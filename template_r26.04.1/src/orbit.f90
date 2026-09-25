! Orbital evolution of the companion on a frozen stellar structure: combines drag, tides, geometry and the
! potential into the decay rate, the dissipated power and diagnostics. Radii in cm, masses in g.

module engulf_orbit

   use star_def
   use const_def, only: dp, pi, standard_cgrav, Rsun, Msun
   use math_lib
   use engulf_grid
   use engulf_potential
   use engulf_planet
   use engulf_drag
   use engulf_tides

   implicit none

   private
   public :: orbit_info, orbit_rates

   ! Diagnostics of the companion at one separation, on the current (frozen) structure.
   type orbit_info
      real(dp) :: a = 0, m_enc = 0, v = 0, cs = 0, Hp = 0, mach = 0
      real(dp) :: R_acc = 0, R_inf = 0          ! accretion radius; max(R_2, R_acc)
      real(dp) :: f_p = 0, f_a = 0               ! engulfed fraction of the physical / accretion cross section
      real(dp) :: rho = 0                        ! mass-weighted mean density over |r-a| < R_inf
      real(dp) :: C_d = 0, C_g = 0, F_drag = 0
      real(dp) :: grav_share = 0                 ! C_g pi R_acc^2 f_a / (C_d pi R_2^2 f_p + C_g pi R_acc^2 f_a)
      real(dp) :: P_drag = 0, P_tide = 0         ! erg/s dissipated by drag / tides
      real(dp) :: t_tide = 0                     ! s (0 = no tides)
      real(dp) :: dedx = 0                       ! d e_orb / da, erg/g/cm
      real(dp) :: dadt_drag = 0, dadt_tide = 0   ! cm/s (negative = inspiral)
      real(dp) :: f_ram = 0, f_roche = 0         ! disruption factors (>= 1 = disrupted)
      real(dp) :: W = 0                          ! half-width of the heating kernel (cm)
      logical :: in_contact = .false., grazing = .false.
   end type orbit_info

contains

   ! All rates and diagnostics for the companion at separation x on the current structure
   ! (needs set_potential for this structure). Controls (inlist):
   !   x_ctrl(1)  M_2 (Msun)          x_ctrl(2)  R_2 (Rsun)
   !   x_ctrl(8)  tidal sigma (Hansen 2010 units, <= 0: no tides)
   !   x_ctrl(9)  alpha for kernel 2 (R_2 + alpha H_P)
   !   x_ctrl(10) C_d: > 0 constant; <= 0 Mach-dependent (O'Connor+23 Eq. 8)
   !   x_ctrl(11) C_g: > 0 constant; <= 0 Ostriker/O'Connor with ln Lambda = ln(H_P / R_inf)
   !   x_integer_ctrl(1) drag law: 0 = draft (C=1, area pi max(R_2,R_acc)^2), 1 = max of hydro and grav
   !                     (O'Connor+23 Eq. 11), 2 = sum
   !   x_integer_ctrl(2) heating kernel: 1 = top-hat |r-a| < R_inf, 2 = top-hat |r-a| < R_2 + alpha H_P,
   !                     3 = top-hat |r-a| < H_P/2 (O'Connor+23 Eq. 27), 4 = Gaussian, sigma = R_inf
   !   x_logical_ctrl(1) tides also when a < R_*
   subroutine orbit_rates(s, x, o)
      type(star_info), pointer :: s
      real(dp), intent(in) :: x
      type(orbit_info), intent(out) :: o
      real(dp) :: M2, R2, e, wk, m1, r1, A_p, A_a, lnLambda, R_star, sum_dm, sum_rho
      integer :: k, kc, k_top, k_bot

      M2 = s% x_ctrl(1)*Msun
      R2 = s% x_ctrl(2)*Rsun
      R_star = s% r(1)
      o% a = x

      call e_orb_specific(s, x, e, o% m_enc, o% dedx)
      o% v = sqrt(standard_cgrav*o% m_enc/x)

      kc = max(1, cell_containing(s, x))
      o% cs = s% csound(kc)
      o% Hp = s% scale_height(kc)
      o% mach = o% v/o% cs
      o% R_acc = accretion_radius(M2, o% v, o% cs)
      o% R_inf = max(R2, o% R_acc)

      o% f_p = intercepted_fraction(x, R2, R_star)
      o% f_a = intercepted_fraction(x, o% R_acc, R_star)
      o% in_contact = (o% f_p > 0d0 .or. o% f_a > 0d0)
      o% grazing = o% in_contact .and. (intercepted_fraction(x, o% R_inf, R_star) < 1d0)

      select case (s% x_integer_ctrl(2))
      case (2)
         o% W = R2 + s% x_ctrl(9)*o% Hp
      case (3)
         o% W = 0.5d0*o% Hp
      case default
         o% W = o% R_inf
      end select

      ! mean density seen by the companion: mass-weighted over |r - x| < R_inf
      o% rho = 0d0
      if (o% in_contact) then
         call cell_range(s, x - o% R_inf, x + o% R_inf, k_top, k_bot)
         sum_dm = 0d0
         sum_rho = 0d0
         do k = k_top, k_bot
            wk = overlap_fraction(s, k, x - o% R_inf, x + o% R_inf)*s% dm(k)
            sum_dm = sum_dm + wk
            sum_rho = sum_rho + wk*s% rho(k)
         end do
         if (sum_dm > 0d0) o% rho = sum_rho/sum_dm
      end if

      ! drag
      if (s% x_ctrl(10) > 0d0) then
         o% C_d = s% x_ctrl(10)
      else
         o% C_d = hydro_drag_coeff(o% mach)
      end if
      if (s% x_ctrl(11) > 0d0) then
         o% C_g = s% x_ctrl(11)
      else
         lnLambda = log(max(o% Hp, o% R_inf)/o% R_inf)
         o% C_g = grav_drag_coeff(o% mach, lnLambda)
      end if
      A_p = o% C_d*pi*R2*R2*o% f_p
      A_a = o% C_g*pi*o% R_acc*o% R_acc*o% f_a
      if (A_p + A_a > 0d0) o% grav_share = A_a/(A_p + A_a)
      select case (s% x_integer_ctrl(1))
      case (0)
         o% F_drag = o% rho*o% v*o% v*pi*o% R_inf*o% R_inf*intercepted_fraction(x, o% R_inf, R_star)
      case (2)
         o% F_drag = o% rho*o% v*o% v*(A_p + A_a)
      case default
         o% F_drag = o% rho*o% v*o% v*max(A_p, A_a)
      end select
      o% P_drag = o% F_drag*o% v

      ! equilibrium tides; inside the star only the enclosed mass and radius a count
      o% t_tide = 0d0
      o% P_tide = 0d0
      if (s% x_ctrl(8) > 0d0 .and. (x > R_star .or. s% x_logical_ctrl(1))) then
         if (x > R_star) then
            m1 = s% m(1)
            r1 = R_star
         else
            m1 = o% m_enc
            r1 = x
         end if
         o% t_tide = tidal_timescale(m1, M2, r1, x, s% x_ctrl(8))
         o% P_tide = M2*o% dedx*x/o% t_tide
      end if

      o% dadt_drag = -o% P_drag/(M2*o% dedx)
      o% dadt_tide = -o% P_tide/(M2*o% dedx)

      o% f_ram = ram_disruption_factor(o% rho, o% v, M2, R2)
      o% f_roche = roche_factor(R2, x, o% m_enc, M2)
   end subroutine orbit_rates

end module engulf_orbit
