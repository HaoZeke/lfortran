! Smoke: array y = sin(x) under --math-backend=pure must call bulk pure_dsin_v
! and match host abs error. Also check IEEE specials via pure scalar ABI.
program test_pure_array_e2e
  use iso_c_binding
  implicit none
  integer, parameter :: n = 10000
  real(c_double) :: x(n), y(n), yh(n), maxerr
  real(c_double) :: qnan, pinf, s
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

  ! This is the production shape: elemental array intrinsic.
  y = sin(x)
  yh = x
  do i = 1, n
     yh(i) = pure_dsin(x(i))
  end do
  maxerr = maxval(abs(y - yh))
  if (maxerr > 1.0d-14) then
     print *, "FAIL array sin vs pure_dsin maxerr=", maxerr
     stop 1
  end if

  qnan = transfer(int(z'7FF8000000000001', 8), qnan)
  pinf = transfer(int(z'7FF0000000000000', 8), pinf)
  s = pure_dsin(qnan)
  if (s == s) then
     print *, "FAIL pure_dsin(NaN) is not NaN"
     stop 2
  end if
  s = pure_dsin(pinf)
  if (s == s) then
     print *, "FAIL pure_dsin(+Inf) is not NaN"
     stop 3
  end if
  s = pure_dsin(-pinf)
  if (s == s) then
     print *, "FAIL pure_dsin(-Inf) is not NaN"
     stop 4
  end if

  print *, "PASS test_pure_array_e2e maxerr=", maxerr
end program
