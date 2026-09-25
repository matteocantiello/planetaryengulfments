! Where the dissipated energy goes: normalised deposition kernels on the MESA mesh.

module engulf_heating

   use star_def
   use const_def, only: dp, convective_mixing
   use math_lib
   use engulf_grid

   implicit none

   private
   public :: add_kernel_heat, envelope_weights

contains

   ! Add energy dE (erg), centred at separation x with kernel half-width W, to heat(1:nz) (erg per cell).
   ! kernel 1-3: uniform per unit mass over |r - x| < W; kernel 4: Gaussian in r with sigma = W, cut at 3 sigma.
   ! The weights are normalised exactly, so sum(heat) increases by dE whenever any cell overlaps the kernel.
   ! Returns .false. if no mass lies in the kernel.
   logical function add_kernel_heat(s, x, W, kernel, dE, heat) result(ok)
      type(star_info), pointer :: s
      real(dp), intent(in) :: x, W, dE
      integer, intent(in) :: kernel
      real(dp), intent(inout) :: heat(:)
      integer :: k, k_top, k_bot
      real(dp) :: reach, dist, wsum
      real(dp), allocatable :: wt(:)

      ok = .false.
      if (kernel == 4) then
         reach = 3d0*W
      else
         reach = W
      end if
      call cell_range(s, x - reach, x + reach, k_top, k_bot)
      if (k_bot < k_top) return
      allocate(wt(k_top:k_bot))
      do k = k_top, k_bot
         if (kernel == 4) then
            dist = max(0d0, inner_radius(s, k) - x, x - s% r(k))
            wt(k) = exp(-(dist/W)**2)*s% dm(k)
            if (overlap_fraction(s, k, x - reach, x + reach) <= 0d0) wt(k) = 0d0
         else
            wt(k) = overlap_fraction(s, k, x - reach, x + reach)*s% dm(k)
         end if
      end do
      wsum = sum(wt)
      if (wsum <= 0d0) return
      heat(k_top:k_bot) = heat(k_top:k_bot) + dE*wt/wsum
      ok = .true.
   end function add_kernel_heat

   ! Mass weights for tidal heat: the outermost convective zone (by mlt_mixing_type); if there is none,
   ! the outer 1% of the mass.
   subroutine envelope_weights(s, w)
      type(star_info), pointer :: s
      real(dp), intent(out) :: w(:)
      integer :: k, k1, k2, nz
      nz = s% nz
      w(1:nz) = 0d0
      k1 = 0
      do k = 1, nz
         if (s% mlt_mixing_type(k) == convective_mixing) then
            k1 = k
            exit
         end if
      end do
      if (k1 > 0) then
         k2 = k1
         do while (k2 < nz)
            if (s% mlt_mixing_type(k2+1) /= convective_mixing) exit
            k2 = k2 + 1
         end do
      else
         k1 = 1
         k2 = 1
         do while (k2 < nz .and. s% m(1) - s% m(k2+1) < 1d-2*s% m(1))
            k2 = k2 + 1
         end do
      end if
      w(k1:k2) = s% dm(k1:k2)/sum(s% dm(k1:k2))
   end subroutine envelope_weights

end module engulf_heating
