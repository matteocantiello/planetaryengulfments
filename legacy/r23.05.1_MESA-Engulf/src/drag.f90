module drag_module

    use star_lib
    use star_def
    use const_def
    use math_lib

    implicit none
  
    private
    public :: calculate_drag
  
  contains
  

  subroutine calculate_drag (m1, m2, area, rho, dt, r, de_drag, dr_drag)

    ! Calculate change in radial position and energy loss due to drag
    ! See Tylenda & Soker 2006, eq B.2 and B.3 (note they have 1/2 in the drag luminosity, we don't)
     
     real(dp), intent(in) ::  m1, m2, area, rho, dt, r
     real(dp), intent(out) :: de_drag, dr_drag
     real(dp) ::  cdr, de_loss

     cdr = 2d0*area*sqrt(standard_cgrav*m1) / m2
     dr_drag = cdr * rho * sqrt(r) * dt
  
     de_loss = dr_drag*standard_cgrav*m1*m2/(2.0_dp*r*r)
     de_drag = de_loss 

   end subroutine calculate_drag
  
end module
  