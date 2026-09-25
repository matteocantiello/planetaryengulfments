
module bondi_module

    use star_lib
    use star_def
    use const_def
    use math_lib

    implicit none
    
    private
    public :: calculate_bondi_radius
  
  contains
  

    subroutine calculate_bondi_radius(m2, sound_speed, v, r_bondi)
  
        ! Calculate Bondi accretion radius
        ! Bondi 1952, MNRAS, 112, 195
    
        implicit none
    
        real(dp), intent(in) :: m2, v, sound_speed
        real(dp), intent(out) :: r_bondi
    
        real(dp), parameter :: cgrav = 6.67408e-8_dp
    
        if (v < sound_speed) then
            r_bondi = 2.0_dp * standard_cgrav * m2 / ( pow(v, 2d0) + pow(sound_speed, 2d0) ) 
        else
            r_bondi = 2.0_dp * standard_cgrav * m2 / pow(v, 2d0)
        end if
  
    end subroutine calculate_bondi_radius
  
  
  end module