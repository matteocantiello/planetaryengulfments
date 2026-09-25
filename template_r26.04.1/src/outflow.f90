! Mass loss driven by the companion.
!
! Option A (x_integer_ctrl(4) = 1): mechanical-ejection prescription. A fraction f_wind of the drag power
!   unbinds surface gas instead of heating, Mdot = f_wind P_drag / e_lift (below). Two forms (x_integer_ctrl(5)):
!   1 (default): f_wind = epsilon = x_ctrl(15), constant. In multi-D a large fraction of the orbital energy goes
!     into bulk motion of gas pushed by the companion's wake and shocks, which a 1D spherical heat source
!     cannot reproduce (option B vs Yang+26: >10x too little ejecta, 2026-09-25). epsilon is calibrated on
!     3D/SPH engulfment and common-envelope simulations.
!   2: f_wind = epsilon * max(0, 1 - 1/Gamma), with Gamma below (switches ejection off in quasi-static regimes).
!   Gamma = P_drag * t_cross / E_bind compares the drag energy deposited in one sound-crossing time of the
!   overlying column (t_cross, the time for the layers to readjust hydrostatically) with the binding energy
!   E_bind of the heated region and all the gas above it (r > a - W, W the kernel half-width). Gamma > 1 means
!   heat arrives faster than the envelope can respond quasi-statically (cf. O'Connor+23 Eqs. 30, 36).
!   (A first version used the thermal time t_th instead; it predicted strong outflows in quasi-static
!   convective envelopes where option B finds no unbound gas, 2026-09-25.)
!   A fraction f_w * max(0, 1 - 1/Gamma) of the drag power (f_w = x_ctrl(15)) goes into unbinding surface gas
!   instead of heating:
!       Mdot = P_wind / e_lift,   e_lift = -(u + v^2/2 - G M/R)_surface + (beta^2/2) v_esc,surf^2
!   with beta = v_inf / v_esc,surf = x_ctrl(16). Deep in an extended envelope Gamma << 1 (no outflow;
!   O'Connor+23); for shallow deposition in compact stars Gamma >> 1 (grazing ejecta; Yarza+25).
!   f_w is to be calibrated against option B.
!
! Option B (x_integer_ctrl(4) = 2): hydrodynamic outflow. All drag energy is deposited as heat; gas in the
!   outermost contiguous cells with positive Bernoulli parameter and outward velocity is removed.

module engulf_outflow

   use star_def
   use const_def, only: dp, standard_cgrav
   use math_lib
   use engulf_grid

   implicit none

   private
   public :: overlying_envelope, surface_lift_energy, unbound_surface_mass

contains

   ! Binding energy (erg, > 0 if bound) of the gas above separation x, sum of (G m/r - u - v^2/2) dm,
   ! its mass, the sound-crossing time from x to the surface, sum of dr/c_s, and the time for heat to
   ! diffuse from x to the surface, sum of c_P T dm / L_surf.
   subroutine overlying_envelope(s, x, E_bind, M_above, t_cross, t_th)
      type(star_info), pointer :: s
      real(dp), intent(in) :: x
      real(dp), intent(out) :: E_bind, M_above, t_cross, t_th
      integer :: k, kx
      real(dp) :: v2
      kx = cell_containing(s, x)
      E_bind = 0d0
      M_above = 0d0
      t_cross = 0d0
      t_th = 0d0
      do k = 1, kx
         v2 = 0d0
         if (s% v_flag) v2 = s% v(k)*s% v(k)
         E_bind = E_bind + (standard_cgrav*s% m(k)/s% r(k) - s% energy(k) - 0.5d0*v2)*s% dm(k)
         M_above = M_above + s% dm(k)
         t_th = t_th + s% cp(k)*s% T(k)*s% dm(k)
         if (k < s% nz) t_cross = t_cross + (s% r(k) - s% r(k+1))/s% csound(k)
      end do
      if (s% L(1) > 0d0) then
         t_th = t_th/s% L(1)
      else
         t_th = huge(1d0)
      end if
   end subroutine overlying_envelope

   ! Energy per unit mass needed to take surface gas to infinity with speed beta * v_esc,surf.
   real(dp) function surface_lift_energy(s, beta) result(e)
      type(star_info), pointer :: s
      real(dp), intent(in) :: beta
      real(dp) :: v2, phi
      v2 = 0d0
      if (s% v_flag) v2 = s% v(1)*s% v(1)
      phi = standard_cgrav*s% m(1)/s% r(1)
      e = phi - s% energy(1) - 0.5d0*v2 + beta*beta*phi
      e = max(e, 1d-3*phi)
   end function surface_lift_energy

   ! Mass (g) in the outermost contiguous cells that are unbound (Bernoulli parameter
   ! v^2/2 + u + P/rho - G m/r > 0) and moving outward; also their total energy (u + v^2/2 - G m/r) dm.
   subroutine unbound_surface_mass(s, M_unb, E_unb)
      type(star_info), pointer :: s
      real(dp), intent(out) :: M_unb, E_unb
      integer :: k
      real(dp) :: v, b
      M_unb = 0d0
      E_unb = 0d0
      if (.not. s% v_flag) return
      do k = 1, s% nz - 1
         v = s% v(k)
         b = 0.5d0*v*v + s% energy(k) + s% Peos(k)/s% rho(k) - standard_cgrav*s% m(k)/s% r(k)
         if (b <= 0d0 .or. v <= 0d0) exit
         M_unb = M_unb + s% dm(k)
         E_unb = E_unb + (0.5d0*v*v + s% energy(k) - standard_cgrav*s% m(k)/s% r(k))*s% dm(k)
      end do
   end subroutine unbound_surface_mass

end module engulf_outflow
