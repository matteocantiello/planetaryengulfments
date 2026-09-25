module search_module

    use star_lib
    use star_def
    use const_def
    use math_lib

    
    implicit none
  
    private
    public :: locate_on_grid, binary_search
  
  contains
  
    
subroutine locate_on_grid(id, separation, radius, k_bottom, k_center, k_top)

    implicit none
    
    integer, intent(in) :: id
    real(dp), intent(in) :: separation, radius  
    integer, intent(out) :: k_center, k_bottom, k_top
    
    integer :: ierr
    type(star_info), pointer :: s
    
    include 'formats'
    ierr = 0
    
    call star_ptr(id, s, ierr)
    if (ierr /= 0) return
  
    call binary_search(s%r, s%nz, separation, k_center)
    call binary_search(s%r, s%nz, separation - radius, k_bottom)
    call binary_search(s%r, s%nz, separation + radius, k_top)
  
    k_center = max(1,k_center)
    k_bottom = max(1,k_bottom) 
    k_top = max(1,k_top)
  
  end subroutine locate_on_grid
  
  
  subroutine binary_search(arr, n, target, idx)
  
    implicit none
    
    real(dp), intent(in) :: arr(:)
    integer, intent(in) :: n
    real(dp), intent(in) :: target 
    integer, intent(out) :: idx
  
    integer :: left, right, mid
  
    right = 1
    left = n
    idx = 0
  
    do while (left >= right)
  
      mid = (left + right) / 2
  
      if (arr(mid) <= target) then
        idx = mid
        left = mid - 1
      else 
        right = mid + 1
      end if
  
    end do
  
  end subroutine binary_search
  
  
  end module
  