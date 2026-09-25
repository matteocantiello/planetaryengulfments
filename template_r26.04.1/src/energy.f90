! Physics of a companion (planet or star, R_2 << R_*) orbiting inside or near a MESA star.
!
! Everything here is evaluated on a frozen stellar structure (the one passed in through s).
! Radii are in cm, masses in g, energies in erg.
!
! Orbital energy uses the star's actual gravitational potential (test-particle companion on a circular orbit):
!     E_orb(a) = M_2 [ G m(a) / (2a) + Phi(a) ],     Phi(a) = -G M_*/R_* - int_a^R_* G m(r)/r^2 dr
! with dE_orb/da = M_2 [ G m(a)/(2a^2) + 2 pi G rho(a) a ].
! Inside each cell the density is taken to be uniform, so m(r), Phi(r) and E_orb(a) are continuous in a and
! E_orb is exactly the integral of its derivative. The heat deposited in a step is M_2 [e(a_old) - e(a_new)].

module energy

   use star_def
   use const_def, only: dp, pi, standard_cgrav, Rsun, Msun, secyer, convective_mixing
   use math_lib

   implicit none

   private
   public :: orbit_info, set_potential, e_orb_specific, orbit_rates, cell_containing, &
      add_kernel_heat, envelope_weights, intercepted_fraction

   ! Diagnostics of the companion at one separation, on the current (frozen) structure.
   type orbit_info
      real(dp) :: a = 0, m_enc = 0, v = 0, cs = 0, Hp = 0, mach = 0
      real(dp) :: R_acc = 0, R_inf = 0          ! accretion radius; max(R_2, R_acc)
      real(dp) :: f_p = 0, f_a = 0               ! engulfed fraction of the physical / accretion cross section
      real(dp) :: rho = 0                        ! mass-weighted mean density over |r-a| < R_inf
      real(dp) :: C_d = 0, C_g = 0, F_drag = 0
      real(dp) :: P_drag = 0, P_tide = 0         ! erg/s dissipated by drag / tides
      real(dp) :: t_tide = 0                     ! s (0 = no tides)
      real(dp) :: dedx = 0                       ! d e_orb / da, erg/g/cm
      real(dp) :: dadt_drag = 0, dadt_tide = 0   ! cm/s (negative = inspiral)
      real(dp) :: f_ram = 0, f_roche = 0         ! disruption factors (>= 1 = disrupted)
      real(dp) :: W = 0                          ! half-width of the heating kernel (cm)
      logical :: in_contact = .false., grazing = .false.
   end type orbit_info

   ! Potential at cell faces for the structure last passed to set_potential.
   real(dp), allocatable :: phi_face(:)

contains

   ! ---------------------------------------------------------------- grid helpers

   real(dp) function inner_radius(s, k)
      type(star_info), pointer :: s
      integer, intent(in) :: k
      if (k < s% nz) then
         inner_radius = s% r(k+1)
      else
         inner_radius = s% R_center
      end if
   end function inner_radius

   real(dp) function inner_mass(s, k)
      type(star_info), pointer :: s
      integer, intent(in) :: k
      if (k < s% nz) then
         inner_mass = s% m(k+1)
      else
         inner_mass = s% M_center
      end if
   end function inner_mass

   ! Cell k with r(k+1) <= x < r(k); 0 if x >= r(1) (outside the star), nz if x is inside the innermost face.
   integer function cell_containing(s, x) result(k)
      type(star_info), pointer :: s
      real(dp), intent(in) :: x
      integer :: lo, hi, mid
      if (x >= s% r(1)) then
         k = 0
         return
      end if
      lo = 1
      hi = s% nz
      do while (lo < hi)
         mid = (lo + hi)/2
         if (inner_radius(s, mid) <= x) then
            hi = mid
         else
            lo = mid + 1
         end if
      end do
      k = lo
   end function cell_containing

   ! 4pi/3 * (mean density) of cell k, i.e. dm / (r_out^3 - r_in^3)
   real(dp) function cell_C(s, k)
      type(star_info), pointer :: s
      integer, intent(in) :: k
      cell_C = s% dm(k) / (pow3(s% r(k)) - pow3(inner_radius(s, k)))
   end function cell_C

   ! int_{r_in}^{x} G m(r)/r^2 dr inside cell k (uniform density)
   real(dp) function g_integral(s, k, x)
      type(star_info), pointer :: s
      integer, intent(in) :: k
      real(dp), intent(in) :: x
      real(dp) :: r_in, C, coef
      r_in = inner_radius(s, k)
      C = cell_C(s, k)
      coef = inner_mass(s, k) - C*pow3(r_in)
      g_integral = 0.5d0*C*(x*x - r_in*r_in)
      if (r_in > 0d0 .and. coef /= 0d0) g_integral = g_integral + coef*(1d0/r_in - 1d0/x)
      g_integral = standard_cgrav*g_integral
   end function g_integral

   ! Tabulate the potential at cell faces; call once per structure.
   subroutine set_potential(s)
      type(star_info), pointer :: s
      integer :: k, nz
      nz = s% nz
      if (allocated(phi_face)) then
         if (size(phi_face) < nz + 1) deallocate(phi_face)
      end if
      if (.not. allocated(phi_face)) allocate(phi_face(nz + 1000))
      phi_face(1) = -standard_cgrav*s% m(1)/s% r(1)
      do k = 1, nz
         phi_face(k+1) = phi_face(k) - g_integral(s, k, s% r(k))
      end do
   end subroutine set_potential

   ! Specific orbital energy e(x) = G m(x)/(2x) + Phi(x); also returns m(x) and de/dx. Needs set_potential.
   subroutine e_orb_specific(s, x, e, m_enc, dedx)
      type(star_info), pointer :: s
      real(dp), intent(in) :: x
      real(dp), intent(out) :: e, m_enc, dedx
      integer :: k
      real(dp) :: r_in, C
      k = cell_containing(s, x)
      if (k == 0) then
         m_enc = s% m(1)
         e = -0.5d0*standard_cgrav*m_enc/x
         dedx = 0.5d0*standard_cgrav*m_enc/(x*x)
         return
      end if
      r_in = inner_radius(s, k)
      C = cell_C(s, k)
      m_enc = inner_mass(s, k) + C*(pow3(x) - pow3(r_in))
      e = 0.5d0*standard_cgrav*m_enc/x + phi_face(k+1) + g_integral(s, k, x)
      dedx = 0.5d0*standard_cgrav*m_enc/(x*x) + 1.5d0*standard_cgrav*C*x
   end subroutine e_orb_specific

   ! Fraction of cell k's volume inside the shell lo < r < hi.
   real(dp) function overlap_fraction(s, k, lo, hi)
      type(star_info), pointer :: s
      integer, intent(in) :: k
      real(dp), intent(in) :: lo, hi
      real(dp) :: r_in, r_out, a, b
      r_in = inner_radius(s, k)
      r_out = s% r(k)
      a = max(r_in, lo)
      b = min(r_out, hi)
      if (b <= a) then
         overlap_fraction = 0d0
      else
         overlap_fraction = (pow3(b) - pow3(a))/(pow3(r_out) - pow3(r_in))
      end if
   end function overlap_fraction

   ! ---------------------------------------------------------------- geometry and drag

   ! Fraction of a disk of radius Rx, centred at separation x, that lies inside radius R_star
   ! (plane-parallel approximation, Rx << R_star).
   real(dp) function intercepted_fraction(x, Rx, R_star) result(f)
      real(dp), intent(in) :: x, Rx, R_star
      real(dp) :: depth, y, alpha
      depth = Rx + R_star - x          ! how far the disk reaches below the surface
      if (Rx <= 0d0 .or. depth <= 0d0) then
         f = 0d0
      else if (depth >= 2d0*Rx) then
         f = 1d0
      else
         y = abs(Rx - depth)
         alpha = acos(min(1d0, y/Rx))
         f = (alpha - (y/Rx)*sin(alpha))/pi      ! circular segment area / (pi Rx^2)
         if (depth > Rx) f = 1d0 - f
      end if
   end function intercepted_fraction

   ! Gravitational drag coefficient (Ostriker 1999), as used by O'Connor et al. 2023 (their Eq. 9) in the
   ! supersonic regime, with the Mach = 1 singularities removed by linear blending over 0.9 < Mach < 1.1
   ! and the result clipped at zero.
   real(dp) function grav_drag_coeff(mach, lnLambda) result(C)
      real(dp), intent(in) :: mach, lnLambda
      real(dp), parameter :: m_lo = 0.9d0, m_hi = 1.1d0
      real(dp) :: w
      if (mach <= m_lo) then
         C = I_sub(mach)
      else if (mach >= m_hi) then
         C = I_sup(mach)
      else
         w = (mach - m_lo)/(m_hi - m_lo)
         C = (1d0 - w)*I_sub(m_lo) + w*I_sup(m_hi)
      end if
      C = max(0d0, C)
   contains
      real(dp) function I_sub(m)
         real(dp), intent(in) :: m
         I_sub = 0.5d0*log((1d0 + m)/(1d0 - m)) - m
      end function I_sub
      real(dp) function I_sup(m)
         real(dp), intent(in) :: m
         I_sup = lnLambda + 0.5d0*log(1d0 - 1d0/(m*m))
      end function I_sup
   end function grav_drag_coeff

   ! Hydrodynamic drag coefficient: fit to Bailey & Hiatt (1972), O'Connor et al. 2023 Eq. 8
   ! (includes the factor 1/2, i.e. F = C_d pi R^2 rho v^2).
   real(dp) function hydro_drag_coeff(mach) result(C)
      real(dp), intent(in) :: mach
      C = 0.375d0 + 0.125d0*tanh(1.75d0*(mach - 1d0))
   end function hydro_drag_coeff

   ! ---------------------------------------------------------------- orbit rates

   ! All rates and diagnostics for the companion at separation x on the current structure.
   ! Controls (inlist):
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
      real(dp) :: M2, R2, e, wk, sigma, m1, r1, A_p, A_a, lnLambda, R_star, sum_dm, sum_rho
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
      o% R_acc = 2d0*standard_cgrav*M2/(o% v*o% v + o% cs*o% cs)
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
      select case (s% x_integer_ctrl(1))
      case (0)
         o% F_drag = o% rho*o% v*o% v*pi*o% R_inf*o% R_inf*intercepted_fraction(x, o% R_inf, R_star)
      case (2)
         o% F_drag = o% rho*o% v*o% v*(A_p + A_a)
      case default
         o% F_drag = o% rho*o% v*o% v*max(A_p, A_a)
      end select
      o% P_drag = o% F_drag*o% v

      ! equilibrium tides (Hut 1981; Eggleton+ 1998; Hansen 2010 Eq. 5)
      o% t_tide = 0d0
      o% P_tide = 0d0
      sigma = s% x_ctrl(8)*6.4d-59
      if (sigma > 0d0 .and. (x > R_star .or. s% x_logical_ctrl(1))) then
         if (x > R_star) then
            m1 = s% m(1)
            r1 = R_star
         else
            m1 = o% m_enc
            r1 = x
         end if
         o% t_tide = (m1/9d0)/((m1 + M2)*M2)*pow(x/r1, 8d0)/(r1*r1*sigma)
         o% P_tide = M2*o% dedx*x/o% t_tide
      end if

      o% dadt_drag = -o% P_drag/(M2*o% dedx)
      o% dadt_tide = -o% P_tide/(M2*o% dedx)

      ! disruption: ram pressure vs binding (Jia & Spruit 2018 Eq. 5) and Roche-lobe overflow
      ! (Eggleton 1983 for M_2 << m, as in O'Connor+23 Eq. 18)
      o% f_ram = o% rho*o% v*o% v/((3d0*M2/(4d0*pi*pow3(R2)))*standard_cgrav*M2/R2)
      o% f_roche = pow3(2d0*R2/x)*o% m_enc/M2
   end subroutine orbit_rates

   ! Cells overlapping lo < r < hi, as k_top <= k <= k_bot (k_top > k_bot if none).
   subroutine cell_range(s, lo, hi, k_top, k_bot)
      type(star_info), pointer :: s
      real(dp), intent(in) :: lo, hi
      integer, intent(out) :: k_top, k_bot
      k_top = max(1, cell_containing(s, hi))
      if (lo <= inner_radius(s, s% nz)) then
         k_bot = s% nz
      else
         k_bot = cell_containing(s, lo)
      end if
      if (hi <= inner_radius(s, s% nz) .or. lo >= s% r(1)) then
         k_top = 1
         k_bot = 0
      end if
   end subroutine cell_range

   ! ---------------------------------------------------------------- heat deposition

   ! Add energy dE (erg), centred at separation x with kernel half-width W, to heat(1:nz) (erg per cell).
   ! The weights are normalised exactly, so sum(heat) increases by dE whenever any cell overlaps the kernel.
   ! Returns .false. if no mass lies in the kernel.
   logical function add_kernel_heat(s, x, W, kernel, dE, heat) result(ok)
      type(star_info), pointer :: s
      real(dp), intent(in) :: x, W, dE
      integer, intent(in) :: kernel
      real(dp), intent(inout) :: heat(:)
      integer :: k, k_top, k_bot
      real(dp) :: reach, dist, wsum
      real(dp), allocatable :: wt(:)

      ok = .false.
      if (kernel == 4) then
         reach = 3d0*W
      else
         reach = W
      end if
      call cell_range(s, x - reach, x + reach, k_top, k_bot)
      if (k_bot < k_top) return
      allocate(wt(k_top:k_bot))
      do k = k_top, k_bot
         if (kernel == 4) then
            dist = max(0d0, inner_radius(s, k) - x, x - s% r(k))
            wt(k) = exp(-(dist/W)**2)*s% dm(k)
            if (overlap_fraction(s, k, x - reach, x + reach) <= 0d0) wt(k) = 0d0
         else
            wt(k) = overlap_fraction(s, k, x - reach, x + reach)*s% dm(k)
         end if
      end do
      wsum = sum(wt)
      if (wsum <= 0d0) return
      heat(k_top:k_bot) = heat(k_top:k_bot) + dE*wt/wsum
      ok = .true.
   end function add_kernel_heat

   ! Mass weights for tidal heat: the outermost convective zone (by mlt_mixing_type); if there is none,
   ! the outer 1% of the mass.
   subroutine envelope_weights(s, w)
      type(star_info), pointer :: s
      real(dp), intent(out) :: w(:)
      integer :: k, k1, k2, nz
      nz = s% nz
      w(1:nz) = 0d0
      k1 = 0
      do k = 1, nz
         if (s% mlt_mixing_type(k) == convective_mixing) then
            k1 = k
            exit
         end if
      end do
      if (k1 > 0) then
         k2 = k1
         do while (k2 < nz)
            if (s% mlt_mixing_type(k2+1) /= convective_mixing) exit
            k2 = k2 + 1
         end do
      else
         k1 = 1
         k2 = 1
         do while (k2 < nz .and. s% m(1) - s% m(k2+1) < 1d-2*s% m(1))
            k2 = k2 + 1
         end do
      end if
      w(k1:k2) = s% dm(k1:k2)/sum(s% dm(k1:k2))
   end subroutine envelope_weights

end module energy
