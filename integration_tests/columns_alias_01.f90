program columns_alias_01
implicit none
integer, parameter :: n = 8
real :: cc(n, 4), ch(n, 4), wa(n)
real :: a, b, c, d
integer :: i, k, ic
do i = 1, n
    wa(i) = real(i)
    do k = 1, 4
        cc(i, k) = real(i + 10*k)
    end do
end do
call cols(n, cc, ch, wa)
! One iteration, written out so it does not depend on the loop the
! vectorizer rewrites. i = 3, ic = n + 2 - i = 7.
i = 3
ic = n + 2 - i
a = cc(i, 1) + cc(ic, 4)
b = cc(i, 1) - cc(ic, 4)
c = cc(i - 1, 1) + cc(ic - 1, 4)
d = cc(i - 1, 1) - cc(ic - 1, 4)
if (ch(i - 1, 1) /= c + d) error stop
if (ch(i, 1) /= a + b) error stop
if (ch(i - 1, 2) /= wa(i - 2)*d - wa(i - 1)*a) error stop
if (ch(i, 2) /= wa(i - 2)*a + wa(i - 1)*d) error stop
if (ch(i - 1, 3) /= c - d) error stop
if (ch(i, 3) /= a - b) error stop
! The untouched tail of the first column stays zero.
if (ch(1, 1) /= 0.0) error stop
if (ch(n, 1) /= 0.0) error stop
end program

subroutine cols(n, cc, ch, wa)
integer, intent(in) :: n
real, intent(in) :: cc(n, 4), wa(n)
real, intent(out) :: ch(n, 4)
integer :: i, ic
real :: a, b, c, d
ch = 0.0
do i = 3, n, 2
    ic = n + 2 - i
    a = cc(i, 1) + cc(ic, 4)
    b = cc(i, 1) - cc(ic, 4)
    c = cc(i - 1, 1) + cc(ic - 1, 4)
    d = cc(i - 1, 1) - cc(ic - 1, 4)
    ch(i - 1, 1) = c + d
    ch(i, 1) = a + b
    ch(i - 1, 2) = wa(i - 2)*d - wa(i - 1)*a
    ch(i, 2) = wa(i - 2)*a + wa(i - 1)*d
    ch(i - 1, 3) = c - d
    ch(i, 3) = a - b
end do
end subroutine
