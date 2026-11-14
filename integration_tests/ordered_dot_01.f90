program ordered_dot_01
! fact = u(1); do k = 2, n; fact = fact + vn(k)*u(k). The lanes of a
! vector product are added in that order, so the bits match a scalar
! accumulation. n = 7 and n = 15 leave a remainder after groups of four.
implicit none
integer :: i, n
external house_dot
integer(8) :: bits
real(8) :: a(16), b(16), s
do i = 1, 16
    a(i) = 1.0d16 / dble(i) + 0.1d0*i
    b(i) = (-1.0d0)**i * (1.0d0 + 1.0d-8*i*i)
end do
n = 7
call house_dot(n, a, b, s)
bits = transfer(s, bits)
if (bits /= int(z'4331163C62715260', 8)) error stop
n = 15
call house_dot(n, a, b, s)
bits = transfer(s, bits)
if (bits /= int(z'43338374A6A1B52F', 8)) error stop
end program

subroutine house_dot(n, vn, u, fact)
integer, intent(in) :: n
real(8), intent(in) :: vn(*), u(*)
real(8), intent(out) :: fact
integer :: k
fact = u(1)
do k = 2, n
    fact = fact + vn(k)*u(k)
end do
fact = fact*2.0d0
end subroutine
