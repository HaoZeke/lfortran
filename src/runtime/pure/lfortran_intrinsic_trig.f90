! Pure Fortran elemental sin/cos (Sollya polynomials).
! Production ABI: lfortran_pure_math_abi.f90 (bind(C) pure_dsin / pure_dsin_v).
!
! IEEE specials: F2003/F2008 ieee_arithmetic (NOT iso_fortran_env).
! iso_fortran_env only provides kinds, I/O units, compiler_version, etc.
! NaN/Inf predicates and quiet NaN values live in ieee_arithmetic:
!   ieee_is_nan, ieee_is_finite, ieee_value(..., ieee_quiet_nan).
! sin/cos of NaN or ±Inf → quiet NaN.
module lfortran_intrinsic_trig
use, intrinsic :: iso_fortran_env, only: sp => real32, dp => real64
use, intrinsic :: ieee_arithmetic, only: ieee_is_nan, ieee_is_finite, &
    ieee_value, ieee_quiet_nan
implicit none
private
public sin, cos, dsin, dcos, ssin, scos
public dsin_v, dcos_v

real(dp), parameter :: halfpi = 1.5707963267948966192313216916398_dp
real(dp), parameter :: inv_pi = 0.3183098861837906715377675267450287_dp
real(dp), parameter :: pi_c1 = 3.14159265358979311600_dp
real(dp), parameter :: pi_c2 = 1.2246467991473532072e-16_dp

real(dp), parameter :: S1 = -0.16666666666666152_dp
real(dp), parameter :: S2 = 8.3333333332824555e-3_dp
real(dp), parameter :: S3 = -1.9841269824216745e-4_dp
real(dp), parameter :: S4 = 2.7557316495396833e-6_dp
real(dp), parameter :: S5 = -2.5051873575598904e-8_dp
real(dp), parameter :: S6 = 1.6047885242898019e-10_dp
real(dp), parameter :: S7 = -7.3707706604864143e-13_dp

real(dp), parameter :: C1 = -0.49999999999999922_dp
real(dp), parameter :: C2 = 4.1666666666658747e-2_dp
real(dp), parameter :: C3 = -1.3888888888610174e-3_dp
real(dp), parameter :: C4 = 2.4801587253930890e-5_dp
real(dp), parameter :: C5 = -2.7557314619119921e-7_dp
real(dp), parameter :: C6 = 2.0876489426058242e-9_dp
real(dp), parameter :: C7 = -1.1461387394717804e-11_dp
real(dp), parameter :: C8 = 4.5963233219481481e-14_dp

interface sin
    module procedure ssin, dsin
end interface
interface cos
    module procedure scos, dcos
end interface

contains

elemental pure function qnan() result(r)
real(dp) :: r
r = ieee_value(0.0_dp, ieee_quiet_nan)
end function

elemental pure function dsin(x) result(r)
real(dp), intent(in) :: x
real(dp) :: r, y, z, sgn, an
integer :: n
if (ieee_is_nan(x) .or. .not. ieee_is_finite(x)) then
    r = qnan()
    return
end if
n = nint(x * inv_pi)
an = real(n, dp)
y = (x - an * pi_c1) - an * pi_c2
sgn = 1.0_dp - 2.0_dp * real(iand(n, 1), dp)
z = y * y
r = sgn * y * (1.0_dp + z*(S1 + z*(S2 + z*(S3 + z*(S4 + z*(S5 + z*(S6 + z*S7)))))))
end function

elemental pure function dcos(x) result(r)
real(dp), intent(in) :: x
real(dp) :: r, y, z, sgn, an
integer :: n
if (ieee_is_nan(x) .or. .not. ieee_is_finite(x)) then
    r = qnan()
    return
end if
n = nint(x * inv_pi)
an = real(n, dp)
y = (x - an * pi_c1) - an * pi_c2
sgn = 1.0_dp - 2.0_dp * real(iand(n, 1), dp)
z = y * y
r = sgn * (1.0_dp + z*(C1 + z*(C2 + z*(C3 + z*(C4 + z*(C5 + z*(C6 + z*(C7 + z*C8))))))))
end function

elemental pure function ssin(x) result(r)
real(sp), intent(in) :: x
real(sp) :: r
r = real(dsin(real(x, dp)), sp)
end function

elemental pure function scos(x) result(r)
real(sp), intent(in) :: x
real(sp) :: r
r = real(dcos(real(x, dp)), sp)
end function

! Contiguous bulk: plain do with CW (auto-vec when not blocked by bind(c) ABI)
subroutine dsin_v(x, y)
real(dp), intent(in)  :: x(:)
real(dp), intent(out) :: y(:)
integer :: i, n, ni
real(dp) :: xi, z, yr, sgn, an
n = min(size(x), size(y))
do i = 1, n
    xi = x(i)
    if (ieee_is_nan(xi) .or. .not. ieee_is_finite(xi)) then
        y(i) = qnan()
        cycle
    end if
    ni = nint(xi * inv_pi)
    an = real(ni, dp)
    yr = (xi - an * pi_c1) - an * pi_c2
    sgn = 1.0_dp - 2.0_dp * real(iand(ni, 1), dp)
    z = yr * yr
    y(i) = sgn * yr * (1.0_dp + z*(S1 + z*(S2 + z*(S3 + z*(S4 + z*(S5 + z*(S6 + z*S7)))))))
end do
end subroutine

subroutine dcos_v(x, y)
real(dp), intent(in)  :: x(:)
real(dp), intent(out) :: y(:)
integer :: i, n, ni
real(dp) :: xi, z, yr, sgn, an
n = min(size(x), size(y))
do i = 1, n
    xi = x(i)
    if (ieee_is_nan(xi) .or. .not. ieee_is_finite(xi)) then
        y(i) = qnan()
        cycle
    end if
    ni = nint(xi * inv_pi)
    an = real(ni, dp)
    yr = (xi - an * pi_c1) - an * pi_c2
    sgn = 1.0_dp - 2.0_dp * real(iand(ni, 1), dp)
    z = yr * yr
    y(i) = sgn * (1.0_dp + z*(C1 + z*(C2 + z*(C3 + z*(C4 + z*(C5 + z*(C6 + z*(C7 + z*C8))))))))
end do
end subroutine

end module
