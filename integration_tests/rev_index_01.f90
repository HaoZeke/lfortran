! A reverse subscript ic = idp2 - i is an affine function of the DO
! variable. The values are the pairwise sums, in source order.
module rev_index_01_mod
implicit none
contains
subroutine fold(n, a, b)
integer, intent(in) :: n
real, intent(in) :: a(n)
real, intent(out) :: b(n)
integer :: i, ic, idp2
idp2 = n + 2
b = 0.0
do i = 3, n, 2
    ic = idp2 - i
    b(i - 1) = a(i - 1) + a(ic - 1)
    b(i) = a(i) + a(ic)
end do
end subroutine fold
end module rev_index_01_mod

program rev_index_01
use rev_index_01_mod
implicit none
integer, parameter :: n = 8
real :: a(n), b(n)
integer :: i
do i = 1, n
    a(i) = real(i)
end do
call fold(n, a, b)
if (b(1) /= 0.0) error stop
if (b(2) /= 8.0) error stop
if (b(3) /= 10.0) error stop
if (b(4) /= 8.0) error stop
if (b(5) /= 10.0) error stop
if (b(6) /= 8.0) error stop
if (b(7) /= 10.0) error stop
if (b(8) /= 0.0) error stop
end program
