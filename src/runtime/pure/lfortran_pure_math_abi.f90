module lfortran_pure_math_abi
use, intrinsic :: iso_c_binding, only: c_double, c_float, c_int
use lfortran_intrinsic_trig, only: dsin, dcos, ssin, scos, dsin_v, dcos_v
implicit none
private
public pure_dsin, pure_dcos, pure_ssin, pure_scos, pure_dsin_v, pure_dcos_v
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
