! Indirect update with a division, as in subsm:
!   d(i) = d(i) + wy(ind(i), p)*wv(jy)/theta + ws(ind(i), p)*wv(js)
! The body is a module procedure called through a pointer, so the arrays
! are not constant and the loop is really generated. --fast --no-fast-math
! must keep the division and the in-order sum. Vectorizing it
! (vgatherqpd + vdivpd) is slower than the scalar loop and is not what
! gfortran -O3 emits.
module gather_div_01_mod
implicit none
contains
subroutine gather_update(n, m, col, ind, wy, ws, wv, d, theta)
integer, intent(in) :: n, m, col, ind(n)
double precision, intent(in) :: wy(n, m), ws(n, m), wv(*), theta
double precision, intent(inout) :: d(n)
integer :: pointr, jy, js, i, k
pointr = 1
do jy = 1, col
    js = col + jy
    do i = 1, n
        k = ind(i)
        d(i) = d(i) + wy(k, pointr) * wv(jy) / theta &
            + ws(k, pointr) * wv(js)
    end do
    pointr = mod(pointr, m) + 1
end do
end subroutine gather_update
end module gather_div_01_mod

program gather_div_01
use gather_div_01_mod
implicit none
integer, parameter :: n = 4, m = 3, col = 2
integer :: ind(n), i, jy
double precision :: wy(n, m), ws(n, m), wv(2 * m), d(n)
procedure(gather_update), pointer :: update
ind = [1, 3, 2, 4]
do i = 1, n
    d(i) = 0.5d0 * i
end do
do jy = 1, m
    do i = 1, n
        wy(i, jy) = 0.1d0 * i + jy
        ws(i, jy) = 0.25d0 * jy - i
    end do
end do
do i = 1, 2 * m
    wv(i) = 0.5d0 * i
end do
update => gather_update
call update(n, m, col, ind, wy, ws, wv, d, 2.0d0)
if (abs(d(1) - (-0.3d0)) > 1.0d-10) error stop
if (abs(d(2) - (-6.65d0)) > 1.0d-10) error stop
if (abs(d(3) - (-2.725d0)) > 1.0d-10) error stop
if (abs(d(4) - (-9.075d0)) > 1.0d-10) error stop
end program
