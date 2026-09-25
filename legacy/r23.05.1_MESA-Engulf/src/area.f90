module area_module

    use star_lib
    use star_def
    use const_def
    use math_lib


    implicit none

  
  !  interface
  !      type, public :: star_info
  !      end interface
  
    private
     public :: calculate_intercepted_area

  
  contains
  
    subroutine calculate_intercepted_area(id, separation, radius, disrupt, area)
  
      ! Calculate intercepted area
  
      integer, intent(in) :: id
      real(dp), intent(in) :: separation, radius, disrupt 
      real(dp), intent(out) :: area
  
      real(dp) :: depth
      type(star_info), pointer :: s
  
      ! Initialization, pointers, checks
  
      depth = calculate_penetration_depth(radius, s%r(1), separation)
  
      ! Do the calculation only if this is a grazing collision and if the planet has not been destroyed yet
      if (depth > 0 .and. separation > s%r(1)-radius .and. disrupt <= 1) then 
        area = intercepted_area(depth, radius) 
      else
        area = pi*radius**2
      end if
  
    contains
  
      function calculate_penetration_depth(radius, rstar, separation)
        real(dp) :: calculate_penetration_depth
        real(dp), intent(in) :: radius, rstar, separation
        calculate_penetration_depth = radius + rstar - separation 
      end function
  
  
      function intercepted_area(x, radius) result(area)
  
        ! Calculate 2D Intercepted area of planet grazing host star noting that the radius is not
        ! necessarily the radius of the planet, it could be the Bondi radius if it is larger.
      
        implicit none
        
        real(dp), intent(in) :: x, radius    
        real(dp) :: area
        real(dp) :: alpha, y
        
        if (x < radius) then ! Case when less than half of the planet is engulfed
        
          y = radius - x
          alpha = acos(y/radius)
          area = radius * (radius*alpha - y*sin(alpha))
          
        else                  ! Case when more than half of the planet is engulfed
      
          y = x - radius
          alpha = acos(y/radius)
          area = pi*radius**2 - radius*(radius*alpha - y*sin(alpha))
          
        end if
      
      end function intercepted_area
  
    end subroutine

  
  end module
  