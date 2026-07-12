! Production pure math ABI — pure Fortran only.
! LFortran --math-backend=pure maps sin/cos to these bind(C) symbols.
!
! Scalar pure_dsin/pure_dcos: leaf Horner + Cody–Waite (no nested calls).
! Array pure_dsin_v: bulk kernel in pure Fortran. Principal-band inputs use a
! vectorizable poly loop; larger |x| uses Cody–Waite. This is not a loop of
! scalar ABI calls.
!
! IEEE specials: F2008 ieee_arithmetic quiet NaN (not iso_fortran_env).
module lfortran_pure_math_abi
use, intrinsic :: iso_c_binding, only: c_double, c_float, c_int
use, intrinsic :: ieee_arithmetic, only: ieee_is_nan, ieee_is_finite, &
    ieee_value, ieee_quiet_nan
implicit none
private
public pure_dsin, pure_dcos, pure_ssin, pure_scos, pure_dsin_v, pure_dcos_v

integer, parameter :: dp = c_double
real(dp), parameter :: halfpi = 1.57079632679489661923_dp
real(dp), parameter :: inv_pi = 0.31830988618379067154_dp
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

contains

elemental pure function qnan() result(r)
real(dp) :: r
r = ieee_value(0.0_dp, ieee_quiet_nan)
end function

real(c_double) function pure_dsin(x) bind(c, name="_lfortran_pure_dsin") result(r)
real(c_double), value, intent(in) :: x
real(dp) :: z, y, sgn, an
integer :: n
if (ieee_is_nan(x) .or. .not. ieee_is_finite(x)) then
    r = qnan()
    return
end if
if (abs(x) <= halfpi) then
    z = x * x
    r = x * (1.0_dp + z*(S1 + z*(S2 + z*(S3 + z*(S4 + z*(S5 + z*(S6 + z*S7)))))))
else
    n = nint(x * inv_pi)
    an = real(n, dp)
    y = (x - an * pi_c1) - an * pi_c2
    sgn = 1.0_dp - 2.0_dp * real(iand(n, 1), dp)
    z = y * y
    r = sgn * y * (1.0_dp + z*(S1 + z*(S2 + z*(S3 + z*(S4 + z*(S5 + z*(S6 + z*S7)))))))
end if
end function

real(c_double) function pure_dcos(x) bind(c, name="_lfortran_pure_dcos") result(r)
real(c_double), value, intent(in) :: x
real(dp) :: z, y, sgn, an
integer :: n
if (ieee_is_nan(x) .or. .not. ieee_is_finite(x)) then
    r = qnan()
    return
end if
if (abs(x) <= halfpi) then
    z = x * x
    r = 1.0_dp + z*(C1 + z*(C2 + z*(C3 + z*(C4 + z*(C5 + z*(C6 + z*(C7 + z*C8)))))))
else
    n = nint(x * inv_pi)
    an = real(n, dp)
    y = (x - an * pi_c1) - an * pi_c2
    sgn = 1.0_dp - 2.0_dp * real(iand(n, 1), dp)
    z = y * y
    r = sgn * (1.0_dp + z*(C1 + z*(C2 + z*(C3 + z*(C4 + z*(C5 + z*(C6 + z*(C7 + z*C8))))))))
end if
end function

real(c_float) function pure_ssin(x) bind(c, name="_lfortran_pure_ssin") result(r)
real(c_float), value, intent(in) :: x
r = real(pure_dsin(real(x, c_double)), c_float)
end function

real(c_float) function pure_scos(x) bind(c, name="_lfortran_pure_scos") result(r)
real(c_float), value, intent(in) :: x
r = real(pure_dcos(real(x, c_double)), c_float)
end function

subroutine work_sin_poly(n, x, y)
integer, intent(in) :: n
real(dp), intent(in) :: x(n)
real(dp), intent(out) :: y(n)
integer :: i
real(dp) :: xi, z
do i = 1, n
    xi = x(i)
    z = xi * xi
    y(i) = xi * (1.0_dp + z*(S1 + z*(S2 + z*(S3 + z*(S4 + z*(S5 + z*(S6 + z*S7)))))))
end do
end subroutine

subroutine work_sin_cw(n, x, y)
integer, intent(in) :: n
real(dp), intent(in) :: x(n)
real(dp), intent(out) :: y(n)
integer :: i, ni
real(dp) :: xi, z, yr, sgn, an
do i = 1, n
    xi = x(i)
    ni = nint(xi * inv_pi)
    an = real(ni, dp)
    yr = (xi - an * pi_c1) - an * pi_c2
    sgn = 1.0_dp - 2.0_dp * real(iand(ni, 1), dp)
    z = yr * yr
    y(i) = sgn * yr * (1.0_dp + z*(S1 + z*(S2 + z*(S3 + z*(S4 + z*(S5 + z*(S6 + z*S7)))))))
end do
end subroutine

subroutine work_cos_poly(n, x, y)
integer, intent(in) :: n
real(dp), intent(in) :: x(n)
real(dp), intent(out) :: y(n)
integer :: i
real(dp) :: xi, z
do i = 1, n
    xi = x(i)
    z = xi * xi
    y(i) = 1.0_dp + z*(C1 + z*(C2 + z*(C3 + z*(C4 + z*(C5 + z*(C6 + z*(C7 + z*C8)))))))
end do
end subroutine

subroutine work_cos_cw(n, x, y)
integer, intent(in) :: n
real(dp), intent(in) :: x(n)
real(dp), intent(out) :: y(n)
integer :: i, ni
real(dp) :: xi, z, yr, sgn, an
do i = 1, n
    xi = x(i)
    ni = nint(xi * inv_pi)
    an = real(ni, dp)
    yr = (xi - an * pi_c1) - an * pi_c2
    sgn = 1.0_dp - 2.0_dp * real(iand(ni, 1), dp)
    z = yr * yr
    y(i) = sgn * (1.0_dp + z*(C1 + z*(C2 + z*(C3 + z*(C4 + z*(C5 + z*(C6 + z*(C7 + z*C8))))))))
end do
end subroutine

! Bulk: one max |x| reduction, then branch-free poly or CW.
! Specials: NaN max (axmax/=axmax) or non-finite max → element-wise pure_dsin.
subroutine pure_dsin_v(n, x, y) bind(c, name="_lfortran_pure_dsin_v")
integer(c_int), value, intent(in) :: n
real(c_double), intent(in)  :: x(n)
real(c_double), intent(out) :: y(n)
integer :: i, j, nn
real(dp) :: axmax
if (n <= 0) return
nn = n
axmax = 0.0_dp
do i = 1, nn
    axmax = max(axmax, abs(x(i)))
end do
if (axmax /= axmax .or. .not. ieee_is_finite(axmax)) then
    do j = 1, nn
        y(j) = pure_dsin(x(j))
    end do
    return
end if
if (axmax <= halfpi) then
    call work_sin_poly(nn, x, y)
else
    call work_sin_cw(nn, x, y)
end if
end subroutine

subroutine pure_dcos_v(n, x, y) bind(c, name="_lfortran_pure_dcos_v")
integer(c_int), value, intent(in) :: n
real(c_double), intent(in)  :: x(n)
real(c_double), intent(out) :: y(n)
integer :: i, j, nn
real(dp) :: axmax
if (n <= 0) return
nn = n
axmax = 0.0_dp
do i = 1, nn
    axmax = max(axmax, abs(x(i)))
end do
if (axmax /= axmax .or. .not. ieee_is_finite(axmax)) then
    do j = 1, nn
        y(j) = pure_dcos(x(j))
    end do
    return
end if
if (axmax <= halfpi) then
    call work_cos_poly(nn, x, y)
else
    call work_cos_cw(nn, x, y)
end if
end subroutine

end module
