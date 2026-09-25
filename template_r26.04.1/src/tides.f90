! Equilibrium tides: Hut (1981), Eggleton et al. (1998), in the form of Hansen (2010) Eq. 5.

module engulf_tides

   use const_def, only: dp
   use math_lib

   implicit none

   private
   public :: tidal_timescale

contains

   ! Orbital decay time a/|da/dt| (s) for a star of mass m1 and radius r1, companion M2 at separation a.
   ! sigma_bar is the dimensionless dissipation constant (Hansen 2010: sigma = sigma_bar * 6.4e-59 cgs).
   real(dp) function tidal_timescale(m1, M2, r1, a, sigma_bar) result(t)
      real(dp), intent(in) :: m1, M2, r1, a, sigma_bar
      real(dp) :: sigma
      sigma = sigma_bar*6.4d-59
      t = (m1/9d0)/((m1 + M2)*M2)*pow(a/r1, 8d0)/(r1*r1*sigma)
   end function tidal_timescale

end module engulf_tides
