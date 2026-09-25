module orbit_module

    use star_lib
    use star_def
    use const_def
    use math_lib

    implicit none
  
    private
    public :: calculate_orbital_velocity
    public :: calculate_orbital_energy
  
  contains
  
    
    subroutine calculate_orbital_velocity(m1, r, v_kepler)
  
    ! Calculate orbital velocity
    ! Use standard Kepler's third law
    
        implicit none
    
        real(dp), intent(in) :: m1, r 
        real(dp), intent(out) :: v_kepler
      
        v_kepler = sqrt(standard_cgrav*m1/r)
    
    end subroutine calculate_orbital_velocity
  
  
    real(dp) function calculate_orbital_energy(m1, m2, r) result(energy)
        real(dp), intent(in) :: m1, m2, r
  
        energy = -standard_cgrav*m1*m2/(2.0_dp*r)
  
    end function calculate_orbital_energy
  
  
  end module