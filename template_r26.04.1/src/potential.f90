! Orbital energy of a test-particle companion on a circular orbit in the star's actual potential:
!     E_orb(a) = M_2 [ G m(a) / (2a) + Phi(a) ],     Phi(a) = -G M_*/R_* - int_a^R_* G m(r)/r^2 dr
!     dE_orb/da = M_2 [ G m(a)/(2a^2) + 2 pi G rho(a) a ]
! With uniform density inside each cell, m(r), Phi(r) and E_orb(a) are continuous and E_orb is exactly the
! integral of its derivative.

module engulf_potential

   use star_def
   use const_def, only: dp, standard_cgrav
   use math_lib
   use engulf_grid

   implicit none

   private
   public :: set_potential, e_orb_specific

   ! Potential at cell faces for the structure last passed to set_potential.
   real(dp), allocatable :: phi_face(:)

contains

   ! int_{r_in}^{x} G m(r)/r^2 dr inside cell k (uniform density)
   real(dp) function g_integral(s, k, x)
      type(star_info), pointer :: s
      integer, intent(in) :: k
      real(dp), intent(in) :: x
      real(dp) :: r_in, C, coef
      r_in = inner_radius(s, k)
      C = cell_C(s, k)
      coef = inner_mass(s, k) - C*pow3(r_in)
      g_integral = 0.5d0*C*(x*x - r_in*r_in)
      if (r_in > 0d0 .and. coef /= 0d0) g_integral = g_integral + coef*(1d0/r_in - 1d0/x)
      g_integral = standard_cgrav*g_integral
   end function g_integral

   ! Tabulate the potential at cell faces; call once per structure.
   subroutine set_potential(s)
      type(star_info), pointer :: s
      integer :: k, nz
      nz = s% nz
      if (allocated(phi_face)) then
         if (size(phi_face) < nz + 1) deallocate(phi_face)
      end if
      if (.not. allocated(phi_face)) allocate(phi_face(nz + 1000))
      phi_face(1) = -standard_cgrav*s% m(1)/s% r(1)
      do k = 1, nz
         phi_face(k+1) = phi_face(k) - g_integral(s, k, s% r(k))
      end do
   end subroutine set_potential

   ! Specific orbital energy e(x) = G m(x)/(2x) + Phi(x); also returns m(x) and de/dx. Needs set_potential.
   subroutine e_orb_specific(s, x, e, m_enc, dedx)
      type(star_info), pointer :: s
      real(dp), intent(in) :: x
      real(dp), intent(out) :: e, m_enc, dedx
      integer :: k
      real(dp) :: r_in, C
      k = cell_containing(s, x)
      if (k == 0) then
         m_enc = s% m(1)
         e = -0.5d0*standard_cgrav*m_enc/x
         dedx = 0.5d0*standard_cgrav*m_enc/(x*x)
         return
      end if
      r_in = inner_radius(s, k)
      C = cell_C(s, k)
      m_enc = inner_mass(s, k) + C*(pow3(x) - pow3(r_in))
      e = 0.5d0*standard_cgrav*m_enc/x + phi_face(k+1) + g_integral(s, k, x)
      dedx = 0.5d0*standard_cgrav*m_enc/(x*x) + 1.5d0*standard_cgrav*C*x
   end subroutine e_orb_specific

end module engulf_potential
