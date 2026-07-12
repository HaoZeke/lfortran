! LFortran smoke: lfortran --math-backend=pure -O3 -o t test_pure_array_e2e.f90
! Under pure, array y=sin(x) lowers to bulk pure_dsin_v; compare to scalar pure_dsin.
program test_pure_array_e2e
  use iso_c_binding
  implicit none
  integer, parameter :: n = 10000
  real(c_double) :: x(n), y(n), maxerr, d, qnan, pinf, s, xx
  integer :: i
  interface
    function pure_dsin(z) bind(c, name="_lfortran_pure_dsin") result(r)
      import :: c_double
      real(c_double), value :: z
      real(c_double) :: r
    end function
  end interface

  do i = 1, n
     x(i) = -1.5d0 + 3.0d0 * real(i - 1, 8) / real(n - 1, 8)
  end do

  y = sin(x)
  maxerr = 0.0_c_double
  do i = 1, n
     xx = x(i)
     d = abs(y(i) - pure_dsin(xx))
     if (d > maxerr) maxerr = d
  end do
  if (maxerr > 1.0d-14) then
     print *, "FAIL array sin vs pure_dsin maxerr=", maxerr
     stop 1
  end if

  qnan = transfer(int(z'7FF8000000000001', 8), qnan)
  pinf = transfer(int(z'7FF0000000000000', 8), pinf)
  s = pure_dsin(qnan)
  if (s == s) stop 2
  s = pure_dsin(pinf)
  if (s == s) stop 3
  s = pure_dsin(-pinf)
  if (s == s) stop 4

  print *, "PASS test_pure_array_e2e maxerr=", maxerr
end program
