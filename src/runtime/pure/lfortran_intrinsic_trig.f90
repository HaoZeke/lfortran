! Pure Fortran sin/cos kernels. Polynomials from Sollya fpminimax
! (see sollya/sin_odd.sollya, sollya/cos_even.sollya).
! Performance-first path: kernel accuracy ~1e-16 on the reduced interval;
! range reduction is still the GSoC21-style fold (not Payne-Hanek).
module lfortran_intrinsic_trig
use, intrinsic :: iso_fortran_env, only: sp => real32, dp => real64
implicit none
private
public sin, cos, dsin, dcos

real(dp), parameter :: pi = 3.1415926535897932384626433832795_dp

interface sin
    module procedure ssin, dsin
end interface

interface cos
    module procedure scos, dcos
end interface

contains

! --- local helpers (dogfooded; not exported) ---------------------------------

elemental real(dp) function tabs(x) result(r)
real(dp), intent(in) :: x
if (x >= 0) then
    r = x
else
    r = -x
end if
end function

elemental integer function tfloor(x) result(r)
real(dp), intent(in) :: x
if (x >= 0) then
    r = x
else
    r = x - 1
end if
end function

elemental real(dp) function tmodulo(x, y) result(r)
real(dp), intent(in) :: x, y
r = x - tfloor(x/y)*y
end function

elemental real(dp) function tmin(x, y) result(r)
real(dp), intent(in) :: x, y
if (x < y) then
    r = x
else
    r = y
end if
end function

elemental real(dp) function tmax(x, y) result(r)
real(dp), intent(in) :: x, y
if (x > y) then
    r = x
else
    r = y
end if
end function

! Fold used by the GSoC21 sin work (Ericson-style), maps into ~[-pi/2, pi/2]
! while preserving sin. Not valid for cos by itself.
elemental real(dp) function reduce_sin_arg(x) result(y)
real(dp), intent(in) :: x
y = tmodulo(x, 2*pi)
y = tmin(y, pi - y)
y = tmax(y, -pi - y)
y = tmin(y, pi - y)
end function

! Reduce for cos: even in x, then fold to [0, pi/2] with sign.
pure elemental subroutine reduce_cos_arg(x, y, s)
real(dp), intent(in) :: x
real(dp), intent(out) :: y, s
y = tabs(x)
y = tmodulo(y, 2*pi)
if (y > pi) then
    y = 2*pi - y
end if
s = 1.0_dp
if (y > pi/2) then
    y = pi - y
    s = -1.0_dp
end if
end subroutine

! --- sin --------------------------------------------------------------------

! Accurate on [-pi/2, pi/2] to about 1e-16 (Sollya relative supnorm ~1.88e-16)
elemental real(dp) function kernel_dsin(x) result(res)
real(dp), intent(in) :: x
real(dp), parameter :: S0 = 1.0_dp
real(dp), parameter :: S1 = -0.16666666666666152_dp
real(dp), parameter :: S2 = 8.3333333332824555e-3_dp
real(dp), parameter :: S3 = -1.9841269824216745e-4_dp
real(dp), parameter :: S4 = 2.7557316495396833e-6_dp
real(dp), parameter :: S5 = -2.5051873575598904e-8_dp
real(dp), parameter :: S6 = 1.6047885242898019e-10_dp
real(dp), parameter :: S7 = -7.3707706604864143e-13_dp
real(dp) :: z
z = x*x
res = x * (S0 + z*(S1 + z*(S2 + z*(S3 + z*(S4 + z*(S5 + z*(S6 + z*S7)))))))
end function

elemental real(dp) function dsin(x) result(r)
real(dp), intent(in) :: x
if (tabs(x) < pi/2) then
    r = kernel_dsin(x)
else
    r = kernel_dsin(reduce_sin_arg(x))
end if
end function

elemental real(sp) function ssin(x) result(r)
real(sp), intent(in) :: x
real(dp) :: tmp
tmp = dsin(real(x, dp))
r = real(tmp, sp)
end function

! --- cos --------------------------------------------------------------------

! Accurate on [-pi/2, pi/2] to about 1e-16 (Sollya absolute supnorm ~5.64e-17)
! Even monoms; leading 1 forced in Sollya formats [|1, D...|].
elemental real(dp) function kernel_dcos(x) result(res)
real(dp), intent(in) :: x
real(dp), parameter :: C0 = 1.0_dp
real(dp), parameter :: C1 = -0.49999999999999922_dp
real(dp), parameter :: C2 = 4.1666666666658747e-2_dp
real(dp), parameter :: C3 = -1.3888888888610174e-3_dp
real(dp), parameter :: C4 = 2.4801587253930890e-5_dp
real(dp), parameter :: C5 = -2.7557314619119921e-7_dp
real(dp), parameter :: C6 = 2.0876489426058242e-9_dp
real(dp), parameter :: C7 = -1.1461387394717804e-11_dp
real(dp), parameter :: C8 = 4.5963233219481481e-14_dp
real(dp) :: z
z = x*x
res = C0 + z*(C1 + z*(C2 + z*(C3 + z*(C4 + z*(C5 + z*(C6 + z*(C7 + z*C8)))))))
end function

elemental real(dp) function dcos(x) result(r)
real(dp), intent(in) :: x
real(dp) :: y, s
if (tabs(x) <= pi/2) then
    r = kernel_dcos(x)
else
    call reduce_cos_arg(x, y, s)
    r = s * kernel_dcos(y)
end if
end function

elemental real(sp) function scos(x) result(r)
real(sp), intent(in) :: x
real(dp) :: tmp
tmp = dcos(real(x, dp))
r = real(tmp, sp)
end function

end module
