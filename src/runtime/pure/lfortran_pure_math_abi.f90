! Production pure math ABI. LFortran --math-backend=pure maps sin/cos to these
! symbols. Scalar path uses principal-band Horner (blog speed win); out of band
! falls through to elemental dsin/dcos.
module lfortran_pure_math_abi
use, intrinsic :: iso_c_binding, only: c_double, c_float, c_int
use lfortran_intrinsic_trig, only: dsin, dcos, ssin, scos, dsin_v, dcos_v
implicit none
private
public pure_dsin, pure_dcos, pure_ssin, pure_scos, pure_dsin_v, pure_dcos_v

real(c_double), parameter :: halfpi = 1.57079632679489661923_c_double
real(c_double), parameter :: S1 = -0.16666666666666152_c_double
real(c_double), parameter :: S2 = 8.3333333332824555e-3_c_double
real(c_double), parameter :: S3 = -1.9841269824216745e-4_c_double
real(c_double), parameter :: S4 = 2.7557316495396833e-6_c_double
real(c_double), parameter :: S5 = -2.5051873575598904e-8_c_double
real(c_double), parameter :: S6 = 1.6047885242898019e-10_c_double
real(c_double), parameter :: S7 = -7.3707706604864143e-13_c_double
real(c_double), parameter :: C1 = -0.49999999999999922_c_double
real(c_double), parameter :: C2 = 4.1666666666658747e-2_c_double
real(c_double), parameter :: C3 = -1.3888888888610174e-3_c_double
real(c_double), parameter :: C4 = 2.4801587253930890e-5_c_double
real(c_double), parameter :: C5 = -2.7557314619119921e-7_c_double
real(c_double), parameter :: C6 = 2.0876489426058242e-9_c_double
real(c_double), parameter :: C7 = -1.1461387394717804e-11_c_double
real(c_double), parameter :: C8 = 4.5963233219481481e-14_c_double

contains

! Fast scalar path: |x|<=pi/2 → pure Horner (no nint). Else elemental.
real(c_double) function pure_dsin(x) bind(c, name="_lfortran_pure_dsin") result(r)
real(c_double), value, intent(in) :: x
real(c_double) :: z
if (abs(x) <= halfpi) then
    z = x * x
    r = x * (1.0_c_double + z*(S1 + z*(S2 + z*(S3 + z*(S4 + z*(S5 + z*(S6 + z*S7)))))))
else
    r = dsin(real(x, kind(0.0d0)))
end if
end function

real(c_double) function pure_dcos(x) bind(c, name="_lfortran_pure_dcos") result(r)
real(c_double), value, intent(in) :: x
real(c_double) :: z
if (abs(x) <= halfpi) then
    z = x * x
    r = 1.0_c_double + z*(C1 + z*(C2 + z*(C3 + z*(C4 + z*(C5 + z*(C6 + z*(C7 + z*C8)))))))
else
    r = dcos(real(x, kind(0.0d0)))
end if
end function

real(c_float) function pure_ssin(x) bind(c, name="_lfortran_pure_ssin") result(r)
real(c_float), value, intent(in) :: x
r = ssin(real(x, kind(0.0)))
end function

real(c_float) function pure_scos(x) bind(c, name="_lfortran_pure_scos") result(r)
real(c_float), value, intent(in) :: x
r = scos(real(x, kind(0.0)))
end function

subroutine pure_dsin_v(n, x, y) bind(c, name="_lfortran_pure_dsin_v")
integer(c_int), value, intent(in) :: n
real(c_double), intent(in)  :: x(n)
real(c_double), intent(out) :: y(n)
call dsin_v(x, y)
end subroutine

subroutine pure_dcos_v(n, x, y) bind(c, name="_lfortran_pure_dcos_v")
integer(c_int), value, intent(in) :: n
real(c_double), intent(in)  :: x(n)
real(c_double), intent(out) :: y(n)
call dcos_v(x, y)
end subroutine

end module
