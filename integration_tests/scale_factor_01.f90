! d(i) = d(i) + a(i)*b/c. Under --fast the invariant b/c is one scale,
! which is what gfortran -O3 -ffast-math computes. (a*b)*(1/c) differs
! in the last bit of this sum.
module scale_factor_01_mod
implicit none
contains
subroutine scale_acc(n, a, b, c, d)
integer, intent(in) :: n
double precision, intent(in) :: a(n), b, c
double precision, intent(inout) :: d(n)
integer :: i
do i = 1, n
    d(i) = d(i) + a(i) * b / c
end do
end subroutine scale_acc
end module scale_factor_01_mod

program scale_factor_01
use scale_factor_01_mod
implicit none
integer, parameter :: n = 64
double precision :: a(n), d(n), b, c, s
integer :: i
procedure(scale_acc), pointer :: acc
b = 0.3d0
c = 0.7d0
s = 0.0d0
do i = 1, n
    a(i) = 0.1d0 * i
    d(i) = 0.4d0
end do
acc => scale_acc
call acc(n, a, b, c, d)
do i = 1, n
    s = s + d(i)
end do
if (abs(s - 1.1474285714285715d2) > 1.0d-12) error stop
end program
