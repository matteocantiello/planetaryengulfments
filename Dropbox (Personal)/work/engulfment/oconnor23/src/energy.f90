module energy

use star_lib
use star_def
use const_def
use math_lib

implicit none 

public
contains

! Useful subroutines and functions
! Calculate change in radial position and energy loss due to drag
subroutine drag (m1, m2, area, rho, dt, r, de, dr)
     real(dp) :: delta_m1, cdr, cde
     real(dp), intent(in) ::  m1, m2, area, rho, dt, r
     real(dp), intent(out) :: de, dr

   ! Calculate Deltar (infall distance due to aerodynamic or gravo- drag)
   ! We consider cross section area of planet. For compact objects (e.g. NS) one needs to use the accretion radius instead.
   ! See e.g. equation B.3 in Tylenda & Soker 2006 (note they have 1/2 in the drag luminosity, we don't)
     cdr = 2d0*area*sqrt(standard_cgrav*m1) / m2
     dr = cdr * rho * sqrt(r) * dt
   ! Calculate DeltaE (energy loss)
   ! See e.g. equation B.2 in Tylenda & Soker 2006, where we have used v = keplerian velocity
    ! cde = (0.5d0*area)*(standard_cgrav*m1)**1.5d0
    ! de = cde *  rho * r**(-1.5d0) * dt
      de =  dr*standard_cgrav*m1*m2/(2d0*r*r)

    ! write(*,'(A,e11.4,2X,A,e11.3,2X,A,e11.3)')&
                        !'From inside drag this is dr=', dr/Rsun,'this is r=',r/Rsun,'this is dt',dt
end subroutine drag

! calculate max cross section for ram pressure vs gravitational dynamical
! friction; added by Chris O'Connor
subroutine get_drag_coeffs (sound_speed, v, smin, smax, C_ram, C_grav)
   real(dp), intent(in) :: sound_speed, v, smin, smax
   real(dp), intent(out) :: C_ram, C_grav
   real(dp) :: mach, mach_sq, arg_of_tanh
   mach = v/sound_speed
   mach_sq = mach*mach
   ! hard sphere drag coefficient from fit to Bailey & Hiatt (1972) data
   arg_of_tanh = 1.75d0 * (mach-1d0)
   C_ram = 0.375d0 + 0.125d0 * tanh(arg_of_tanh)
   ! gravitational drag coefficient from Ostriker (1999)
   if (mach < 1d0) then
     C_grav = 5d-1 * log((1d0+mach)/(1d0-mach)) - mach
   else 
     C_grav = log(smax/smin) - 0.5d0 * log(mach_sq / (mach_sq - 1d0))
   end if
end subroutine get_drag_coeffs

! Calculate orbital velocity
subroutine orbital_velocity(m1, r, v_kepler)
     real(dp), intent(in)  :: m1, r
     real(dp), intent(out) :: v_kepler
   ! use const_def, only: standard_cgrav
     v_kepler = sqrt(standard_cgrav*m1/r)
end subroutine orbital_velocity

! Calculate tidal timescale
! This is a derivative of the equilibrium tide model of Hut 1981 formulated by Eggleton + 1998 (EKH)
! In particular we use equation (5) from Hansen et al. 2010
  subroutine tidal_timescale(m1, m2, r1, r2, a, sigma_calibration, t_tide)
       real(dp), intent(in)  :: m1, m2, r1, r2, a, sigma_calibration
       real(dp), intent(out) :: t_tide
       real(dp) :: sigma
     ! use const_def, only: standard_cgrav
      ! sigma_calibration = 7.8d-8  ! Calibrated dissipation constant (Hansen et al. 2010)
      sigma = 6.4d-59 * sigma_calibration ! Dimensional Scaling for dissipation constant (Hansen et al. 2010)
      t_tide = (m1/9.0)/((m1+m2)*m2) * (a**8.0 / r1**10) / sigma
      ! write(*,*) '(m1/9.0)/((m1+m2)*m2)' , t_tide
  end subroutine tidal_timescale


subroutine bondi_radius (m2, sound_speed, v, R_bondi)
     real(dp), intent(in)  :: m2, v, sound_speed
     real(dp), intent(out) :: R_bondi
     if (v < sound_speed) then
          R_Bondi = 2.d0 * standard_cgrav * m2 / ( pow(v, 2d0) + pow(sound_speed, 2d0) )
     else
          R_bondi = 2.d0 * standard_cgrav * m2 / pow(v, 2d0)
     endif
  !   write(*,*)'Inside Bondi SUB: this is m2, sound_speed, v, R_bondi', &
  !              m2/Msun, sound_speed/1.d5, v/1.d5, R_bondi/Rsun
end subroutine bondi_radius

! Calculate binary orbital energy
subroutine orbital_energy(m1, m2, r, energy)
     real(dp), intent(in) ::  m1, m2,  r
     real(dp), intent(out) :: energy
   ! use const_def, only: standard_cgrav
     energy = -standard_cgrav*m1*m2/(2d0*r)
!     write(*,*)'Inside orbital energy SUB: this is m1, m2, r, energy', &
!                m1/Msun, m2/Msun, r/Rsun, energy
end subroutine orbital_energy

subroutine locate_on_grid(id, Orbital_separation, R_companion, krr_bottom ,krr_center, krr_top)
     implicit none
     integer, intent(in) :: id
     real(dp), intent(in) :: Orbital_separation, R_companion
     integer, intent(out):: krr_center, krr_bottom, krr_top
     integer :: ierr

     type (star_info), pointer :: s
         include 'formats'
         ierr = 0
         call star_ptr(id, s, ierr)
         if (ierr /= 0) return

       krr_center=1

       do while (krr_center >= 1 .and. krr_center < s% nz .and. s% r(krr_center) >= Orbital_separation)
          krr_center = krr_center + 1
       end do

       krr_bottom=1
        do while (krr_bottom >= 1 .and. &
                  krr_bottom < s% nz .and. &
                  s% r(krr_bottom) >= Orbital_separation-R_companion)
            krr_bottom = krr_bottom + 1
        end do
      krr_top = krr_center
        do while (krr_top >= 2 .and. s% r(krr_top) < Orbital_separation+R_companion)
            krr_top = krr_top - 1
        end do
end subroutine locate_on_grid


real(dp) function calculate_orbital_energy(m1, m2, r) result(energy)
     real(dp), intent(in) :: m1, m2, r

     energy = -standard_cgrav*m1*m2/(2d0*r)

end function calculate_orbital_energy

! Calculate 2D Intercepted area of planet grazing host star noting that the radius is not
! necessarily the radius of the planet, it could be the Bondi radius if it is larger.
! R_companion = max (planet radius, Bondi radius), x = Rstar-Orbital_separation (see sketch)
real(dp) function intercepted_area(x, R_inf) result(area)
     real(dp), intent(in) :: x, R_inf
     real(dp) :: alpha, y

   ! Case when less than half of the planet is engulfed
     if (x < R_inf) then
          y = R_inf - x
          alpha = acos (y/R_inf)
          area = R_inf * (R_inf*alpha - y * sin(alpha))
      !    write(*,*)'From intercepted_area SUB: less than half: x,R_inf,alpha,area', x/Rsun, R_inf/Rsun, alpha, area
     else
   ! Case when more than half of the planet is engulfed
          y = x - R_inf
          alpha = acos (y/R_inf)
          area = pi*pow(R_inf, 2d0) - R_inf * (R_inf*alpha - (y * sin(alpha)))
      !    write(*,*)'From intercepted_area SUB: more than half: x,R_inf,alpha,area', x/Rsun, R_inf/Rsun, alpha, area
     endif
end function intercepted_area

real(dp) function penetration_depth_function(R_influence, R_star, Orbital_separation) result(penetration_depth)
     real(dp) :: R_influence, R_star, Orbital_separation
     penetration_depth = R_influence + R_star - Orbital_separation
     if (penetration_depth < 0d0) penetration_depth = 0d0
    ! write(*,*)'From penetration_depth, R_influence,Orbital_separation,penetration_depth' &
    ! ,R_influence,Orbital_separation,penetration_depth
end function penetration_depth_function

real(dp) function check_disruption(M_companion,R_companion,v_planet,rho_ambient) result(f)
   ! f > 1 means disruption. This is expected when the ram pressure integrated
   ! over the planet cross section approaches the planet binding energy
     real(dp), intent(in) :: M_companion,R_companion,v_planet,rho_ambient
     real(dp) :: v_esc_planet_square, rho_planet
     rho_planet = 3d0*M_companion/(4d0*pi*pow(R_companion, 3d0))
     v_esc_planet_square = standard_cgrav*M_companion/R_companion
   ! Eq.5 in Jia & Spruit 2018  https://arxiv.org/abs/1808.00467
     f = (rho_ambient*pow(v_planet, 2d0)) / (rho_planet*v_esc_planet_square)
    ! write(*,*)'From Check_Disruption rho_ambient, rho_planet, v_planet, f', &
    !           rho_ambient, rho_planet, v_planet, f
end function check_disruption

! tidal disruption / Roche lobe overflow -- added by Chris O'Connor 2023 Feb 09
real(dp) function check_disruption_tides(M_companion,R_companion, M_enclosed, Orbital_separation) result(ftide)
   ! ftide > 1 means disruption by tidal forces.
   ! We use the formula for the Roche lobe volume due to Eggleton (1983, ApJ,
   ! 268, 368) in the limit M_companion / M_enclosed << 1 
    real(dp), intent(in) :: M_companion,R_companion,M_enclosed,Orbital_separation
    ftide = pow((2d0 * R_companion / Orbital_separation), 3d0) * (M_enclosed / M_companion)
end function check_disruption_tides



real(dp) function TukeyWindow(x,a)
   use const_def, only: dp, pi
   real(dp), intent(in) :: x, a

   if ((x .le. -0.5) .or. (x .ge. 0.5)) then
      TukeyWindow = 0.
   else if (x .le. -0.5 + a) then
      TukeyWindow = 0.5 - 0.5*cos(pi*(x+0.5)/a)
   else if (x .ge. 0.5 - a) then
      TukeyWindow = 0.5 - 0.5*cos(-pi*(x-0.5)/a)
   else
      TukeyWindow = 1.
   endif

end function TukeyWindow
      
end module energy