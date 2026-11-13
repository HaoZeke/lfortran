! cos and sin are locals passed into a rotation on every iteration.
! Their addresses must stay stable, and a local the callee writes must
! come back updated.
module givens_rota_01_mod
implicit none
contains
subroutine rota(c, s, a, b)
double precision :: c, s, a, b
double precision :: s1, s2
s1 = a
s2 = b
b = c * s2 + s * s1
a = c * s1 - s * s2
end subroutine rota
subroutine addtwo(x)
double precision :: x
x = x + 2.0d0
end subroutine addtwo
end module givens_rota_01_mod

program givens_rota_01
use givens_rota_01_mod
implicit none
double precision :: c, s, a, b, z
integer :: i
procedure(rota), pointer :: rotate
c = 0.5d0
s = 0.25d0
a = 4.0d0
b = 8.0d0
rotate => rota
do i = 1, 2
    call rotate(c, s, a, b)
end do
if (a /= -1.25d0) error stop
if (b /= 2.5d0) error stop
z = 1.0d0
call addtwo(z)
if (z /= 3.0d0) error stop
end program
