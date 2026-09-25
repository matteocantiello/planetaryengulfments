! Locating radii on the MESA mesh. Cell k lies between r(k+1) (inner face) and r(k) (outer face);
! k = 1 is the surface cell. Inside each cell the density is taken to be uniform.

module engulf_grid

   use star_def
   use const_def, only: dp
   use math_lib

   implicit none

   private
   public :: inner_radius, inner_mass, cell_containing, cell_range, cell_C, overlap_fraction

contains

   real(dp) function inner_radius(s, k)
      type(star_info), pointer :: s
      integer, intent(in) :: k
      if (k < s% nz) then
         inner_radius = s% r(k+1)
      else
         inner_radius = s% R_center
      end if
   end function inner_radius

   real(dp) function inner_mass(s, k)
      type(star_info), pointer :: s
      integer, intent(in) :: k
      if (k < s% nz) then
         inner_mass = s% m(k+1)
      else
         inner_mass = s% M_center
      end if
   end function inner_mass

   ! Cell k with r(k+1) <= x < r(k); 0 if x >= r(1) (outside the star), nz if x is inside the innermost face.
   integer function cell_containing(s, x) result(k)
      type(star_info), pointer :: s
      real(dp), intent(in) :: x
      integer :: lo, hi, mid
      if (x >= s% r(1)) then
         k = 0
         return
      end if
      lo = 1
      hi = s% nz
      do while (lo < hi)
         mid = (lo + hi)/2
         if (inner_radius(s, mid) <= x) then
            hi = mid
         else
            lo = mid + 1
         end if
      end do
      k = lo
   end function cell_containing

   ! Cells overlapping lo < r < hi, as k_top <= k <= k_bot (k_top > k_bot if none).
   subroutine cell_range(s, lo, hi, k_top, k_bot)
      type(star_info), pointer :: s
      real(dp), intent(in) :: lo, hi
      integer, intent(out) :: k_top, k_bot
      k_top = max(1, cell_containing(s, hi))
      if (lo <= inner_radius(s, s% nz)) then
         k_bot = s% nz
      else
         k_bot = cell_containing(s, lo)
      end if
      if (hi <= inner_radius(s, s% nz) .or. lo >= s% r(1)) then
         k_top = 1
         k_bot = 0
      end if
   end subroutine cell_range

   ! 4pi/3 * (mean density) of cell k, i.e. dm / (r_out^3 - r_in^3)
   real(dp) function cell_C(s, k)
      type(star_info), pointer :: s
      integer, intent(in) :: k
      cell_C = s% dm(k) / (pow3(s% r(k)) - pow3(inner_radius(s, k)))
   end function cell_C

   ! Fraction of cell k's volume inside the shell lo < r < hi.
   real(dp) function overlap_fraction(s, k, lo, hi)
      type(star_info), pointer :: s
      integer, intent(in) :: k
      real(dp), intent(in) :: lo, hi
      real(dp) :: r_in, r_out, a, b
      r_in = inner_radius(s, k)
      r_out = s% r(k)
      a = max(r_in, lo)
      b = min(r_out, hi)
      if (b <= a) then
         overlap_fraction = 0d0
      else
         overlap_fraction = (pow3(b) - pow3(a))/(pow3(r_out) - pow3(r_in))
      end if
   end function overlap_fraction

end module engulf_grid
