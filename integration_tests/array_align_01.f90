program array_align_01
implicit none
! 2500 doubles is below the mmap threshold, so an ordinary malloc
! returns storage 16 bytes off a 32-byte boundary. BLAS kernels and
! gfortran's local numeric arrays use 32-byte alignment.
double precision :: a(2500)
integer(8) :: p
a(1) = 1.0d0
p = loc(a)
if (mod(p, 32_8) /= 0_8) error stop
end program
