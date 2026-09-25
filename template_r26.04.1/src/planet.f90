! Properties of the companion itself: how much of it is inside the star, and whether it is disrupted.

module engulf_planet

   use const_def, only: dp, pi, standard_cgrav
   use math_lib

   implicit none

   private
   public :: intercepted_fraction, ram_disruption_factor, roche_factor

contains

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

   ! Ram pressure vs the companion's binding-energy density (Jia & Spruit 2018, Eq. 5); >= 1 means disrupted.
   real(dp) function ram_disruption_factor(rho, v, M2, R2) result(f)
      real(dp), intent(in) :: rho, v, M2, R2
      f = rho*v*v/((3d0*M2/(4d0*pi*pow3(R2)))*standard_cgrav*M2/R2)
   end function ram_disruption_factor

   ! Roche-lobe overflow for M2 << m_enc (Eggleton 1983; O'Connor+23 Eq. 18); >= 1 means disrupted.
   real(dp) function roche_factor(R2, a, m_enc, M2) result(f)
      real(dp), intent(in) :: R2, a, m_enc, M2
      f = pow3(2d0*R2/a)*m_enc/M2
   end function roche_factor

end module engulf_planet
