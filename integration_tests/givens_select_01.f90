! The two Givens branches in r1mpyq. One side divides, the other stores
! the parameter, and each side takes one square root. The result is the
! rotation (cos, sin) and one application of it.
module givens_select_01_mod
implicit none
contains
subroutine givens_pair(v, cos, sin)
double precision, intent(in) :: v
double precision, intent(out) :: cos, sin
double precision :: one
one = 1.0d0
cos = 0.0d0
sin = 0.0d0
if (abs(v) > one) cos = one / v
if (abs(v) > one) sin = sqrt(one - cos * cos)
if (abs(v) <= one) sin = v
if (abs(v) <= one) cos = sqrt(one - sin * sin)
end subroutine givens_pair
end module givens_select_01_mod

program givens_select_01
use givens_select_01_mod
implicit none
double precision :: v, cos, sin, aj, an
procedure(givens_pair), pointer :: pair
pair => givens_pair
v = 2.0d0
call pair(v, cos, sin)
if (abs(cos - 0.5d0) > 1.0d-12) error stop
if (abs(sin - sqrt(0.75d0)) > 1.0d-12) error stop
v = 0.5d0
call pair(v, cos, sin)
if (abs(sin - 0.5d0) > 1.0d-12) error stop
if (abs(cos - sqrt(0.75d0)) > 1.0d-12) error stop
aj = cos * 3.0d0 - sin * 4.0d0
an = sin * 3.0d0 + cos * 4.0d0
if (abs(aj - (sqrt(0.75d0) * 3.0d0 - 0.5d0 * 4.0d0)) > 1.0d-12) error stop
if (abs(an - (0.5d0 * 3.0d0 + sqrt(0.75d0) * 4.0d0)) > 1.0d-12) error stop
end program
