! Drag on the companion: accretion radius and drag coefficients.
! Convention: F = C rho v^2 pi R^2, i.e. the usual factor 1/2 is absorbed in C.

module engulf_drag

   use const_def, only: dp, standard_cgrav
   use math_lib

   implicit none

   private
   public :: accretion_radius, hydro_drag_coeff, grav_drag_coeff

contains

   ! Accretion radius R_acc = 2 G M_2 / (v^2 + c_s^2), continuous through Mach 1 (Bondi 1952; Iben & Livio 1993).
   real(dp) function accretion_radius(M2, v, cs)
      real(dp), intent(in) :: M2, v, cs
      accretion_radius = 2d0*standard_cgrav*M2/(v*v + cs*cs)
   end function accretion_radius

   ! Hydrodynamic drag coefficient: fit to Bailey & Hiatt (1972), O'Connor et al. 2023 Eq. 8.
   real(dp) function hydro_drag_coeff(mach) result(C)
      real(dp), intent(in) :: mach
      C = 0.375d0 + 0.125d0*tanh(1.75d0*(mach - 1d0))
   end function hydro_drag_coeff

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

end module engulf_drag
