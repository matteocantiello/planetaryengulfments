! Engulfment of a companion (planet or star, R_2 << R_*) by a MESA star, MESA r26.04.1.
!
! Each step (other_energy, called once per step attempt before the solver):
!   - the orbit is integrated with RK4 sub-steps on the start-of-step structure, from the committed separation
!     a = s% xtra(i_a), under drag and (optionally) equilibrium tides;
!   - the energy released is exactly E_orb(a_old) - E_orb(a_new), with E_orb in the star's actual potential
!     (potential.f90). The drag part is deposited along the path with a normalised kernel. The tidal part goes
!     into the convective envelope (x_logical_ctrl(2)) or is only booked;
!   - nothing is committed. extras_finish_step commits the new separation and the energy ledger to
!     s% xtra / s% lxtra, which MESA restores on retries and writes to photos.
!
! Physics modules: grid, potential, planet, drag, tides, heating, orbit (.f90).
! Controls (see also orbit.f90, orbit_rates):
!   x_ctrl(1)  M_2 (Msun)                    x_ctrl(2)  R_2 (Rsun)
!   x_ctrl(3)  stop the orbit at a < this (Rsun); <= 0 to disable
!   x_ctrl(4)  max |da| per step / kernel half-width while grazing
!   x_ctrl(5)  max |da| per step / kernel half-width when fully engulfed
!   x_ctrl(6)  initial separation (Rsun)
!   x_ctrl(7)  max |da|/a per step from tides
!   x_ctrl(8)  tidal sigma (Hansen 2010 units); <= 0: no tides
!   x_ctrl(9)  alpha in R_2 + alpha H_P (kernel 2)
!   x_ctrl(10) C_d (> 0 constant, <= 0 Mach-dependent)   x_ctrl(11) C_g (> 0 constant, <= 0 Ostriker)
!   x_ctrl(12) after disruption, evolve this many Kelvin-Helmholtz times, then stop (<= 0: 10)
!   x_ctrl(13) minimum number of orbit sub-steps per step (<= 0: 10)
!   x_ctrl(14) mesh refinement around the companion: ~cells per kernel half-width (<= 0: off;
!              needs use_other_mesh_functions = .true.)
!   x_integer_ctrl(1) drag law (0 draft, 1 max, 2 sum)   x_integer_ctrl(2) heating kernel (1-4)
!   x_integer_ctrl(3) terminal output every this many models (<= 0: 10)
!   x_integer_ctrl(4) outflow: 0 none, 1 option A (energy-limited prescription), 2 option B (hydrodynamic;
!                     remove unbound surface gas). Needs use_other_adjust_mdot = .true. (outflow.f90)
!   x_ctrl(15) f_w, efficiency of option A      x_ctrl(16) beta = v_inf / v_esc,surf of the outflow (A)
!   x_logical_ctrl(1) tides also when a < R_*            x_logical_ctrl(2) deposit tidal heat in the envelope

module run_star_extras

   use star_lib
   use star_def
   use const_def
   use math_lib
   use auto_diff
   use engulf_potential, only: set_potential, e_orb_specific
   use engulf_orbit, only: orbit_info, orbit_rates
   use engulf_heating, only: add_kernel_heat, envelope_weights
   use engulf_outflow, only: overlying_envelope, surface_lift_energy, unbound_surface_mass

   implicit none

   ! persistent state in s% xtra / s% lxtra (restored on retries, saved in photos)
   integer, parameter :: i_a = 1              ! separation (cm)
   integer, parameter :: i_E_drag = 2         ! cumulative drag energy deposited (erg)
   integer, parameter :: i_E_tide = 3         ! cumulative tidal energy dissipated (erg)
   integer, parameter :: i_E_tide_dep = 4     ! cumulative tidal energy deposited (erg)
   integer, parameter :: i_E_heat_code = 5    ! cumulative sum(extra_heat*dm*dt) as set by this code (erg)
   integer, parameter :: i_E_heat_mesa = 6    ! cumulative s% total_extra_heating as integrated by MESA (erg)
   integer, parameter :: i_E_err_mesa = 7     ! cumulative signed s% error_in_energy_conservation (erg)
   integer, parameter :: i_W_pot = 8          ! cumulative change of E_orb from changes of the potential (erg)
   integer, parameter :: i_E_orb0 = 9         ! E_orb at the start of the run (erg)
   integer, parameter :: i_stop_age = 10      ! age (yr) at which to stop after disruption; < 0 unset
   integer, parameter :: i_a_stop = 11        ! separation at disruption (cm)
   integer, parameter :: i_E_wind = 12        ! cumulative drag energy given to the outflow instead of heat (A)
   integer, parameter :: i_M_wind = 13        ! cumulative mass removed by the engulfment outflow (g)
   integer, parameter :: i_E_unfunded = 14    ! outflow energy exceeding the drag energy available (should be 0)
   integer, parameter :: i_E_unb = 15         ! cumulative energy (u + v^2/2 - Gm/r) of gas removed in option B
   integer, parameter :: i_active = 1         ! lxtra: companion still orbiting

   ! results of the current step attempt (recomputed on every attempt; committed in extras_finish_step)
   integer :: trial_model = -1
   real(dp) :: a_trial = 0, dE_drag_trial = 0, dE_tide_trial = 0, dE_tide_dep_trial = 0, heat_trial = 0
   real(dp) :: e_end_start_struct = 0, P_ratio_trial = 1, heated_mass_trial = 0
   integer :: nsub_trial = 0
   logical :: destroyed_trial = .false.
   character(len=32) :: destroy_reason = ''
   type(orbit_info) :: o_step                 ! at the committed separation, start-of-step structure
   type(orbit_info) :: o_now                  ! at the committed separation, end-of-step structure
   real(dp) :: E_orb_now = 0, dt_limit_now = 0
   real(dp), allocatable :: heat(:), wenv(:)

   ! outflow set in engulf_adjust_mdot for the current step attempt
   integer :: mdot_model = -1
   real(dp) :: mdot_eng = 0, e_lift = 0, Gamma_now = 0, f_wind_now = 0, E_bind_now = 0, M_above_now = 0, &
      t_th_now = 0, t_cross_now = 0, E_unb_trial = 0, E_wind_trial = 0, E_unfunded_trial = 0

contains

   subroutine extras_controls(id, ierr)
      integer, intent(in) :: id
      integer, intent(out) :: ierr
      type(star_info), pointer :: s
      ierr = 0
      call star_ptr(id, s, ierr)
      if (ierr /= 0) return

      s% other_energy => engulf_energy
      s% other_adjust_mdot => engulf_adjust_mdot
      s% how_many_other_mesh_fcns => how_many_engulf_mesh_fcns
      s% other_mesh_fcn_data => engulf_mesh_fcn_data

      s% extras_startup => extras_startup
      s% extras_start_step => extras_start_step
      s% extras_check_model => extras_check_model
      s% extras_finish_step => extras_finish_step
      s% extras_after_evolve => extras_after_evolve
      s% how_many_extra_history_columns => how_many_extra_history_columns
      s% data_for_extra_history_columns => data_for_extra_history_columns
      s% how_many_extra_profile_columns => how_many_extra_profile_columns
      s% data_for_extra_profile_columns => data_for_extra_profile_columns
      s% how_many_extra_history_header_items => how_many_extra_history_header_items
      s% data_for_extra_history_header_items => data_for_extra_history_header_items
      s% how_many_extra_profile_header_items => how_many_extra_profile_header_items
      s% data_for_extra_profile_header_items => data_for_extra_profile_header_items
   end subroutine extras_controls


   ! ------------------------------------------------------------------------ heating

   subroutine engulf_energy(id, ierr)
      integer, intent(in) :: id
      integer, intent(out) :: ierr
      type(star_info), pointer :: s
      type(orbit_info) :: o1, o2, o3, o4, oc
      integer :: k, j, nz, nsub, kernel
      real(dp) :: M2, dt, a0, x, xn, h, k1, k2, k3, k4, Pd, Pt, Ed, Et, dEd, &
         e0, e1, m_enc, dedx, dE_tot, fd, a_stop, rate, xmid
      logical :: ok

      ierr = 0
      call star_ptr(id, s, ierr)
      if (ierr /= 0) return
      nz = s% nz
      do k = 1, nz
         s% extra_heat(k) = 0d0
      end do
      trial_model = -1
      if (s% doing_relax) return
      if (.not. s% lxtra(i_active)) return

      call ensure_work_arrays(nz)
      M2 = s% x_ctrl(1)*Msun
      dt = s% dt
      a0 = s% xtra(i_a)
      kernel = s% x_integer_ctrl(2)
      if (kernel < 1 .or. kernel > 4) kernel = 1
      a_stop = s% x_ctrl(3)*Rsun

      call set_potential(s)
      call orbit_rates(s, a0, o_step)

      rate = abs(o_step% dadt_drag + o_step% dadt_tide)
      nsub = max(1, nint(s% x_ctrl(13)))
      if (s% x_ctrl(13) <= 0d0) nsub = 10
      if (rate > 0d0) nsub = max(nsub, min(5000, ceiling(20d0*rate*dt/o_step% W)))

      heat(1:nz) = 0d0
      destroyed_trial = .false.
      destroy_reason = ''
      x = a0
      Ed = 0d0
      Et = 0d0
      h = dt/nsub
      if (rate > 0d0) then
         do j = 1, nsub
            call orbit_rates(s, x, o1)
            k1 = o1% dadt_drag + o1% dadt_tide
            call orbit_rates(s, max(x + 0.5d0*h*k1, 1d-3*x), o2)
            k2 = o2% dadt_drag + o2% dadt_tide
            call orbit_rates(s, max(x + 0.5d0*h*k2, 1d-3*x), o3)
            k3 = o3% dadt_drag + o3% dadt_tide
            call orbit_rates(s, max(x + h*k3, 1d-3*x), o4)
            k4 = o4% dadt_drag + o4% dadt_tide
            xn = max(x + h*(k1 + 2d0*k2 + 2d0*k3 + k4)/6d0, 1d-3*x)
            Pd = (o1% P_drag + 2d0*o2% P_drag + 2d0*o3% P_drag + o4% P_drag)/6d0
            Pt = (o1% P_tide + 2d0*o2% P_tide + 2d0*o3% P_tide + o4% P_tide)/6d0
            dEd = Pd*h
            if (dEd > 0d0) then
               xmid = 0.5d0*(x + xn)
               ok = add_kernel_heat(s, xmid, o2% W, kernel, dEd, heat)
               ! kernel entirely above the surface (possible while grazing): put the heat in the surface layer
               if (.not. ok) ok = add_kernel_heat(s, s% r(1), o2% W, 1, dEd, heat)
            end if
            Ed = Ed + dEd
            Et = Et + Pt*h
            x = xn
            call orbit_rates(s, x, oc)
            if (oc% f_ram >= 1d0) then
               destroy_reason = 'ram pressure'
            else if (oc% f_roche >= 1d0) then
               destroy_reason = 'Roche-lobe overflow'
            else if (x < a_stop) then
               destroy_reason = 'stop radius x_ctrl(3)'
            else if (x <= oc% R_inf .or. x <= 2d-3*a0) then
               destroy_reason = 'reached the centre'
            end if
            if (len_trim(destroy_reason) > 0) then
               destroyed_trial = .true.
               exit
            end if
         end do
      end if

      ! exact energy released: difference of the orbital energy in the (start-of-step) potential
      call e_orb_specific(s, a0, e0, m_enc, dedx)
      call e_orb_specific(s, x, e1, m_enc, dedx)
      dE_tot = M2*(e0 - e1)
      if (Ed + Et > 0d0) then
         fd = Ed/(Ed + Et)
         P_ratio_trial = (Ed + Et)/dE_tot
      else
         fd = 0d0
         P_ratio_trial = 1d0
      end if
      dE_drag_trial = fd*dE_tot
      dE_tide_trial = dE_tot - dE_drag_trial

      ! option A: the energy carried off by the outflow set for this step is withheld from the drag heat
      E_wind_trial = 0d0
      E_unfunded_trial = 0d0
      if (s% x_integer_ctrl(4) == 1 .and. mdot_model == s% model_number) then
         E_wind_trial = mdot_eng*dt*e_lift
         if (E_wind_trial > dE_drag_trial) then
            E_unfunded_trial = E_wind_trial - dE_drag_trial
            E_wind_trial = dE_drag_trial
         end if
      end if
      if (Ed > 0d0) heat(1:nz) = heat(1:nz)*((dE_drag_trial - E_wind_trial)/Ed)

      dE_tide_dep_trial = 0d0
      if (dE_tide_trial > 0d0 .and. s% x_logical_ctrl(2)) then
         call envelope_weights(s, wenv)
         heat(1:nz) = heat(1:nz) + dE_tide_trial*wenv(1:nz)
         dE_tide_dep_trial = dE_tide_trial
      end if

      do k = 1, nz
         s% extra_heat(k) = heat(k)/(s% dm(k)*dt)
      end do
      heat_trial = sum(heat(1:nz))
      heated_mass_trial = sum(s% dm(1:nz), mask=heat(1:nz) > 0d0)

      a_trial = x
      e_end_start_struct = e1
      nsub_trial = nsub
      trial_model = s% model_number
   end subroutine engulf_energy


   subroutine ensure_work_arrays(nz)
      integer, intent(in) :: nz
      if (allocated(heat)) then
         if (size(heat) < nz) deallocate(heat, wenv)
      end if
      if (.not. allocated(heat)) allocate(heat(nz + 1000), wenv(nz + 1000))
   end subroutine ensure_work_arrays


   ! Limit the next timestep so the companion moves at most a fraction of the kernel width (drag) or of
   ! its separation (tides) per step.
   subroutine limit_dt(s, o)
      type(star_info), pointer :: s
      type(orbit_info), intent(in) :: o
      real(dp) :: lim, tol
      lim = huge(1d0)
      if (o% in_contact .and. abs(o% dadt_drag) > 0d0) then
         if (o% grazing) then
            tol = s% x_ctrl(4)
         else
            tol = s% x_ctrl(5)
         end if
         lim = tol*o% W/abs(o% dadt_drag)
      end if
      if (abs(o% dadt_tide) > 0d0) lim = min(lim, s% x_ctrl(7)*o% a/abs(o% dadt_tide))
      dt_limit_now = lim
      if (lim < s% dt_next) s% dt_next = lim
   end subroutine limit_dt


   ! Refinement around the companion: gval = N tanh((r - a)/W) puts ~N cells in each kernel half-width.
   subroutine how_many_engulf_mesh_fcns(id, n)
      integer, intent(in) :: id
      integer, intent(out) :: n
      n = 1
   end subroutine how_many_engulf_mesh_fcns

   subroutine engulf_mesh_fcn_data(id, nfcns, names, gval_is_xa_function, vals1, ierr)
      integer, intent(in) :: id
      integer, intent(in) :: nfcns
      character(len=*) :: names(:)
      logical, intent(out) :: gval_is_xa_function(:)
      real(dp), pointer :: vals1(:)
      integer, intent(out) :: ierr
      type(star_info), pointer :: s
      real(dp), pointer :: vals(:, :)
      real(dp) :: a, W
      integer :: k, nz
      ierr = 0
      call star_ptr(id, s, ierr)
      if (ierr /= 0) return
      nz = s% nz
      names(1) = 'engulf_refine'
      gval_is_xa_function(1) = .false.
      vals(1:nz, 1:nfcns) => vals1(1:nz*nfcns)
      vals(1:nz, 1) = 0d0
      if (s% x_ctrl(14) <= 0d0 .or. .not. s% lxtra(i_active)) return
      a = s% xtra(i_a)
      W = o_now% W
      if (W <= 0d0) W = s% x_ctrl(2)*Rsun
      if (a > s% r(1) + 3d0*W) return
      do k = 1, nz
         vals(k, 1) = s% x_ctrl(14)*tanh((s% r(k) - a)/W)
      end do
   end subroutine engulf_mesh_fcn_data


   ! ------------------------------------------------------------------------ outflow (outflow.f90)

   ! Called by MESA after the standard winds are set and before mass is removed, once per step attempt.
   subroutine engulf_adjust_mdot(id, ierr)
      integer, intent(in) :: id
      integer, intent(out) :: ierr
      type(star_info), pointer :: s
      type(orbit_info) :: o
      real(dp) :: M_unb
      ierr = 0
      call star_ptr(id, s, ierr)
      if (ierr /= 0) return
      mdot_model = -1
      mdot_eng = 0d0
      E_unb_trial = 0d0
      Gamma_now = 0d0
      f_wind_now = 0d0
      if (s% doing_relax) return

      select case (s% x_integer_ctrl(4))
      case (1)
         if (.not. s% lxtra(i_active)) return
         call set_potential(s)
         call orbit_rates(s, s% xtra(i_a), o)
         if (o% P_drag <= 0d0) return
         ! the gas that must be unbound: the heated region and everything above it
         call overlying_envelope(s, max(s% xtra(i_a) - o% W, s% R_center), E_bind_now, M_above_now, &
            t_cross_now, t_th_now)
         if (E_bind_now > 0d0) then
            Gamma_now = o% P_drag*t_cross_now/E_bind_now
         else
            Gamma_now = huge(1d0)
         end if
         f_wind_now = min(1d0, s% x_ctrl(15)*max(0d0, 1d0 - 1d0/Gamma_now))
         e_lift = surface_lift_energy(s, s% x_ctrl(16))
         mdot_eng = min(f_wind_now*o% P_drag/e_lift, 0.5d0*M_above_now/s% dt)
      case (2)
         call unbound_surface_mass(s, M_unb, E_unb_trial)
         mdot_eng = M_unb/s% dt
      case default
         return
      end select
      s% mstar_dot = s% mstar_dot - mdot_eng
      mdot_model = s% model_number
   end subroutine engulf_adjust_mdot


   ! ------------------------------------------------------------------------ step hooks

   subroutine extras_startup(id, restart, ierr)
      integer, intent(in) :: id
      logical, intent(in) :: restart
      integer, intent(out) :: ierr
      type(star_info), pointer :: s
      real(dp) :: e, m_enc, dedx
      ierr = 0
      call star_ptr(id, s, ierr)
      if (ierr /= 0) return
      if (.not. restart) then
         s% xtra(:) = 0d0
         s% lxtra(:) = .false.
         s% lxtra(i_active) = .true.
         s% xtra(i_a) = s% x_ctrl(6)*Rsun
         s% xtra(i_stop_age) = -1d0
         call set_potential(s)
         call e_orb_specific(s, s% xtra(i_a), e, m_enc, dedx)
         s% xtra(i_E_orb0) = s% x_ctrl(1)*Msun*e
      end if
      call update_now(s)
      ! the first step must obey the same orbital limits as the others (the loaded model's dt can be ~Myr)
      if (.not. restart .and. s% lxtra(i_active)) call limit_dt(s, o_now)
      write(*, '(a,f10.5,a,l2,a,es11.3,a)') ' engulfment: a =', s% xtra(i_a)/Rsun, ' Rsun, active =', &
         s% lxtra(i_active), ', first dt =', s% dt_next/secyer, ' yr'
   end subroutine extras_startup


   ! Diagnostics at the committed separation on the current structure.
   subroutine update_now(s)
      type(star_info), pointer :: s
      real(dp) :: e, m_enc, dedx
      call set_potential(s)
      call orbit_rates(s, s% xtra(i_a), o_now)
      call e_orb_specific(s, s% xtra(i_a), e, m_enc, dedx)
      E_orb_now = s% x_ctrl(1)*Msun*e
   end subroutine update_now


   integer function extras_start_step(id)
      integer, intent(in) :: id
      extras_start_step = 0
   end function extras_start_step


   integer function extras_check_model(id)
      integer, intent(in) :: id
      extras_check_model = keep_going
   end function extras_check_model


   integer function extras_finish_step(id)
      integer, intent(in) :: id
      integer :: ierr, every
      type(star_info), pointer :: s
      real(dp) :: M2, e, m_enc, dedx, relax
      ierr = 0
      call star_ptr(id, s, ierr)
      if (ierr /= 0) return
      extras_finish_step = keep_going
      M2 = s% x_ctrl(1)*Msun

      ! MESA's own integral of what it received, and its energy error, for every step
      s% xtra(i_E_heat_mesa) = s% xtra(i_E_heat_mesa) + s% total_extra_heating
      s% xtra(i_E_err_mesa) = s% xtra(i_E_err_mesa) + s% error_in_energy_conservation

      if (trial_model == s% model_number .and. s% lxtra(i_active)) then
         s% xtra(i_a) = a_trial
         s% xtra(i_E_drag) = s% xtra(i_E_drag) + dE_drag_trial
         s% xtra(i_E_tide) = s% xtra(i_E_tide) + dE_tide_trial
         s% xtra(i_E_tide_dep) = s% xtra(i_E_tide_dep) + dE_tide_dep_trial
         s% xtra(i_E_heat_code) = s% xtra(i_E_heat_code) + heat_trial
         s% xtra(i_E_wind) = s% xtra(i_E_wind) + E_wind_trial
         s% xtra(i_E_unfunded) = s% xtra(i_E_unfunded) + E_unfunded_trial
         ! E_orb at the new separation changes as the star evolves under the companion
         call set_potential(s)
         call e_orb_specific(s, a_trial, e, m_enc, dedx)
         s% xtra(i_W_pot) = s% xtra(i_W_pot) + M2*(e - e_end_start_struct)
         if (destroyed_trial) then
            s% lxtra(i_active) = .false.
            s% xtra(i_a_stop) = a_trial
            relax = s% x_ctrl(12)
            if (relax <= 0d0) relax = 10d0
            s% xtra(i_stop_age) = s% star_age + relax*s% kh_timescale
            write(*, '(a,a,a,f10.5,a,es11.3,a)') ' engulfment: companion destroyed (', trim(destroy_reason), &
               ') at a =', a_trial/Rsun, ' Rsun; relaxing until age', s% xtra(i_stop_age), ' yr'
         end if
      end if
      trial_model = -1
      if (mdot_model == s% model_number) then
         s% xtra(i_M_wind) = s% xtra(i_M_wind) + mdot_eng*s% dt
         s% xtra(i_E_unb) = s% xtra(i_E_unb) + E_unb_trial
      end if
      mdot_model = -1

      call update_now(s)
      if (s% lxtra(i_active)) call limit_dt(s, o_now)

      every = s% x_integer_ctrl(3)
      if (every <= 0) every = 10
      if (mod(s% model_number, every) == 0) &
         write(*, '(a,i8,a,f10.5,a,es10.3,a,es10.3,a,f6.3,a,es10.3)') ' engulf', s% model_number, &
            '  a/Rsun', s% xtra(i_a)/Rsun, '  L_drag/Lsun', o_now% P_drag/Lsun, &
            '  E_dep', s% xtra(i_E_drag) + s% xtra(i_E_tide_dep), '  f_eng', o_now% f_p, &
            '  (E_code-E_mesa)/E_dep', ledger_residual(s)

      if (s% xtra(i_stop_age) > 0d0 .and. s% star_age > s% xtra(i_stop_age)) then
         write(*, *) 'engulfment: thermal relaxation after disruption complete'
         extras_finish_step = terminate
      end if
      if (extras_finish_step == terminate) s% termination_code = t_extras_finish_step
   end function extras_finish_step


   ! Heat this code set vs heat MESA integrated, relative to the heat deposited.
   real(dp) function ledger_residual(s)
      type(star_info), pointer :: s
      real(dp) :: dep
      dep = s% xtra(i_E_heat_code)
      if (dep > 0d0) then
         ledger_residual = (s% xtra(i_E_heat_code) - s% xtra(i_E_heat_mesa))/dep
      else
         ledger_residual = 0d0
      end if
   end function ledger_residual


   subroutine extras_after_evolve(id, ierr)
      integer, intent(in) :: id
      integer, intent(out) :: ierr
      ierr = 0
   end subroutine extras_after_evolve


   ! ------------------------------------------------------------------------ output

   integer function how_many_extra_history_columns(id)
      integer, intent(in) :: id
      how_many_extra_history_columns = 47
   end function how_many_extra_history_columns


   subroutine data_for_extra_history_columns(id, n, names, vals, ierr)
      integer, intent(in) :: id, n
      character(len=maxlen_history_column_name) :: names(n)
      real(dp) :: vals(n)
      integer, intent(out) :: ierr
      type(star_info), pointer :: s
      real(dp) :: E_dep, M2
      ierr = 0
      call star_ptr(id, s, ierr)
      if (ierr /= 0) return
      M2 = s% x_ctrl(1)*Msun
      E_dep = s% xtra(i_E_drag) + s% xtra(i_E_tide_dep)

      names(1) = 'engulf_a';                vals(1) = s% xtra(i_a)/Rsun           ! Rsun
      names(2) = 'engulf_active';           vals(2) = merge(1d0, 0d0, s% lxtra(i_active))
      names(3) = 'engulf_v_orb';            vals(3) = o_now% v/1d5                ! km/s
      names(4) = 'engulf_mach';             vals(4) = o_now% mach
      names(5) = 'engulf_m_enc';            vals(5) = o_now% m_enc/Msun
      names(6) = 'engulf_R_acc';            vals(6) = o_now% R_acc/Rsun
      names(7) = 'engulf_f_eng_p';          vals(7) = o_now% f_p                  ! engulfed fraction, R_2
      names(8) = 'engulf_f_eng_acc';        vals(8) = o_now% f_a                  ! engulfed fraction, R_acc
      names(9) = 'engulf_rho';              vals(9) = o_now% rho
      names(10) = 'engulf_C_d';             vals(10) = o_now% C_d
      names(11) = 'engulf_C_g';             vals(11) = o_now% C_g
      names(12) = 'engulf_F_drag';          vals(12) = o_now% F_drag              ! dyn
      names(13) = 'engulf_L_drag';          vals(13) = o_now% P_drag/Lsun         ! Lsun
      names(14) = 'engulf_L_tide';          vals(14) = o_now% P_tide/Lsun         ! Lsun
      names(15) = 'engulf_t_inspiral';      vals(15) = safe_div(o_now% a, &
                                               abs(o_now% dadt_drag + o_now% dadt_tide))/secyer
      names(16) = 'engulf_t_tide';          vals(16) = o_now% t_tide/secyer
      names(17) = 'engulf_f_ram';           vals(17) = o_now% f_ram
      names(18) = 'engulf_f_roche';         vals(18) = o_now% f_roche
      names(19) = 'engulf_kernel_W';        vals(19) = o_now% W/Rsun
      names(20) = 'engulf_heated_mass';     vals(20) = heated_mass_trial/Msun
      names(21) = 'engulf_nsub';            vals(21) = nsub_trial
      names(22) = 'engulf_power_ratio';     vals(22) = P_ratio_trial   ! int P dt / Delta E_orb in last step
      names(23) = 'engulf_dt_limit';        vals(23) = dt_limit_now/secyer
      ! energy ledger (erg)
      names(24) = 'engulf_E_orb';           vals(24) = E_orb_now      ! actual potential, current structure
      names(25) = 'engulf_E_orb_pointmass'; vals(25) = -standard_cgrav*o_now% m_enc*M2/(2d0*s% xtra(i_a))
      names(26) = 'engulf_E_drag_cum';      vals(26) = s% xtra(i_E_drag)
      names(27) = 'engulf_E_tide_cum';      vals(27) = s% xtra(i_E_tide)
      names(28) = 'engulf_E_tide_dep_cum';  vals(28) = s% xtra(i_E_tide_dep)
      names(29) = 'engulf_E_heat_code_cum'; vals(29) = s% xtra(i_E_heat_code)
      names(30) = 'engulf_E_heat_mesa_cum'; vals(30) = s% xtra(i_E_heat_mesa)
      names(31) = 'engulf_W_pot_cum';       vals(31) = s% xtra(i_W_pot)
      ! E_orb(t) - [E_orb(0) - E_drag - E_tide + W_pot]: zero unless the potential changes between steps
      names(32) = 'engulf_orbit_ledger_resid'; vals(32) = E_orb_now - (s% xtra(i_E_orb0) - s% xtra(i_E_drag) &
                                               - s% xtra(i_E_tide) + s% xtra(i_W_pot))
      names(33) = 'engulf_heat_ledger_rel';  vals(33) = ledger_residual(s)   ! (code - MESA)/deposited
      names(34) = 'engulf_E_err_mesa_cum';   vals(34) = s% xtra(i_E_err_mesa)
      names(35) = 'engulf_E_err_rel_dep';    vals(35) = safe_div(s% xtra(i_E_err_mesa), E_dep)
      names(36) = 'engulf_a_stop';           vals(36) = s% xtra(i_a_stop)/Rsun
      ! outflow (outflow.f90)
      names(37) = 'engulf_Gamma';            vals(37) = min(Gamma_now, 1d99)
      names(38) = 'engulf_f_wind';           vals(38) = f_wind_now
      names(39) = 'engulf_mdot_wind';        vals(39) = mdot_eng/Msun*secyer      ! Msun/yr
      names(40) = 'engulf_M_wind_cum';       vals(40) = s% xtra(i_M_wind)/Msun
      names(41) = 'engulf_E_wind_cum';       vals(41) = s% xtra(i_E_wind)
      names(42) = 'engulf_E_unfunded_cum';   vals(42) = s% xtra(i_E_unfunded)
      names(43) = 'engulf_E_unb_removed_cum'; vals(43) = s% xtra(i_E_unb)
      names(44) = 'engulf_E_bind_above';     vals(44) = E_bind_now
      names(45) = 'engulf_M_above';          vals(45) = M_above_now/Msun
      names(46) = 'engulf_t_th';             vals(46) = t_th_now/secyer
      names(47) = 'engulf_t_cross';          vals(47) = t_cross_now/secyer
   contains
      real(dp) function safe_div(a, b)
         real(dp), intent(in) :: a, b
         if (b /= 0d0) then
            safe_div = a/b
         else
            safe_div = 0d0
         end if
      end function safe_div
   end subroutine data_for_extra_history_columns


   integer function how_many_extra_profile_columns(id)
      integer, intent(in) :: id
      how_many_extra_profile_columns = 1
   end function how_many_extra_profile_columns


   subroutine data_for_extra_profile_columns(id, n, nz, names, vals, ierr)
      integer, intent(in) :: id, n, nz
      character(len=maxlen_profile_column_name) :: names(n)
      real(dp) :: vals(nz, n)
      integer, intent(out) :: ierr
      type(star_info), pointer :: s
      integer :: k
      ierr = 0
      call star_ptr(id, s, ierr)
      if (ierr /= 0) return
      names(1) = 'engulf_heat'   ! erg/g/s
      do k = 1, nz
         vals(k, 1) = s% extra_heat(k)% val
      end do
   end subroutine data_for_extra_profile_columns


   integer function how_many_extra_history_header_items(id)
      integer, intent(in) :: id
      how_many_extra_history_header_items = 0
   end function how_many_extra_history_header_items


   subroutine data_for_extra_history_header_items(id, n, names, vals, ierr)
      integer, intent(in) :: id, n
      character(len=maxlen_history_column_name) :: names(n)
      real(dp) :: vals(n)
      integer, intent(out) :: ierr
      ierr = 0
   end subroutine data_for_extra_history_header_items


   integer function how_many_extra_profile_header_items(id)
      integer, intent(in) :: id
      how_many_extra_profile_header_items = 0
   end function how_many_extra_profile_header_items


   subroutine data_for_extra_profile_header_items(id, n, names, vals, ierr)
      integer, intent(in) :: id, n
      character(len=maxlen_profile_column_name) :: names(n)
      real(dp) :: vals(n)
      integer, intent(out) :: ierr
      ierr = 0
   end subroutine data_for_extra_profile_header_items

end module run_star_extras
