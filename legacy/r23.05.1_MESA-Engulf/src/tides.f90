
module tides_module

    use star_lib
    use star_def
    use const_def
    use math_lib

    implicit none
  
    private
    public :: calculate_tidal_timescale
  
  contains
  

  subroutine calculate_tidal_timescale(m1, m2, r1, r2, a, sigma_cal, t_tide)

    ! Calculate tidal timescale
    ! Uses equilibrium tide model of Hut 1981 and Eggleton+ 1998 (EKH)
    ! Equation (5) from Hansen et al. 2010
    
    implicit none
  
    real(dp), intent(in) :: m1, m2, r1, r2, a, sigma_cal
    real(dp), intent(out) :: t_tide
    
    real(dp) :: sigma
    
    sigma = 6.4e-59_dp * sigma_cal  ! Dimensional Scaling for dissipation constant (Hansen et al. 2010)
  
    t_tide = (m1/9.0_dp)/((m1+m2)*m2) * (a**8.0_dp / r1**10.0_dp) / sigma
  
  end subroutine calculate_tidal_timescale
  
  end module