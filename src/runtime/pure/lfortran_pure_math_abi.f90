! Compile-time pure math backend ABI.
! When --math-backend=pure, IntrinsicElementalFunction instantiate binds
! _lfortran_pure_{s,d}{sin,cos} instead of _lfortran_{s,d}{sin,cos} (libm).
! Selection is fixed at compile/link time; no per-call branch.
module lfortran_pure_math_abi
use, intrinsic :: iso_c_binding, only: c_double, c_float
use lfortran_intrinsic_trig, only: dsin, dcos, ssin, scos
implicit none
private
public pure_dsin, pure_dcos, pure_ssin, pure_scos

contains

real(c_double) function pure_dsin(x) bind(c, name="_lfortran_pure_dsin") result(r)
real(c_double), value, intent(in) :: x
r = dsin(real(x, kind(0.0d0)))
end function

real(c_double) function pure_dcos(x) bind(c, name="_lfortran_pure_dcos") result(r)
real(c_double), value, intent(in) :: x
r = dcos(real(x, kind(0.0d0)))
end function

real(c_float) function pure_ssin(x) bind(c, name="_lfortran_pure_ssin") result(r)
real(c_float), value, intent(in) :: x
r = ssin(real(x, kind(0.0)))
end function

real(c_float) function pure_scos(x) bind(c, name="_lfortran_pure_scos") result(r)
real(c_float), value, intent(in) :: x
r = scos(real(x, kind(0.0)))
end function

end module
