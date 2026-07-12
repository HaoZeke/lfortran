! Drive production pure bulk ABI symbols from the installable archive.
program test_pure_bulk_abi
  use iso_c_binding
  implicit none
  interface
    function pure_dsin(x) bind(c, name="_lfortran_pure_dsin") result(r)
      import :: c_double
      real(c_double), value :: x
      real(c_double) :: r
    end function
    function pure_dcos(x) bind(c, name="_lfortran_pure_dcos") result(r)
      import :: c_double
      real(c_double), value :: x
      real(c_double) :: r
    end function
    function host_sin(x) bind(c, name="sin") result(r)
      import :: c_double
      real(c_double), value :: x
      real(c_double) :: r
    end function
    subroutine pure_dsin_v(n, x, y) bind(c, name="_lfortran_pure_dsin_v")
      import :: c_int, c_double
      integer(c_int), value :: n
      real(c_double) :: x(n), y(n)
    end subroutine
    subroutine pure_dcos_v(n, x, y) bind(c, name="_lfortran_pure_dcos_v")
      import :: c_int, c_double
      integer(c_int), value :: n
      real(c_double) :: x(n), y(n)
    end subroutine
  end interface

  integer, parameter :: n = 4096, n_grid = 4001
  real(c_double) :: x(n), ys(n), yc(n), yh(n), maxerr_s, maxerr_c, xx, es, ms
  real(c_double) :: qnan, pinf, xs(4), ys4(4)
  integer :: i, n10

  do i = 1, n
     x(i) = -1.5_c_double + 3.0_c_double * real(i - 1, c_double) / real(n - 1, c_double)
  end do

  call pure_dsin_v(n, x, ys)
  call pure_dcos_v(n, x, yc)
  do i = 1, n
     yh(i) = host_sin(x(i))
  end do
  maxerr_s = maxval(abs(ys - yh))
  maxerr_c = 0.0_c_double
  do i = 1, n
     maxerr_c = max(maxerr_c, abs(yc(i) - cos(x(i))))
  end do
  if (maxerr_s > 1.0e-14_c_double .or. maxerr_c > 1.0e-14_c_double) then
     print *, "FAIL bulk band maxerr", maxerr_s, maxerr_c
     stop 1
  end if

  do i = 1, n
     x(i) = -20.0_c_double + 40.0_c_double * real(i - 1, c_double) / real(n - 1, c_double)
  end do
  call pure_dsin_v(n, x, ys)
  maxerr_s = 0.0_c_double
  do i = 1, n
     maxerr_s = max(maxerr_s, abs(ys(i) - pure_dsin(x(i))))
  end do
  if (maxerr_s > 1.0e-14_c_double) then
     print *, "FAIL bulk large vs scalar pure", maxerr_s
     stop 2
  end if

  ms = 0.0_c_double
  n10 = 0
  do i = 0, n_grid - 1
     xx = -20.0_c_double + 40.0_c_double * real(i, c_double) / real(n_grid - 1, c_double)
     es = abs(pure_dsin(xx) - host_sin(xx))
     if (es > ms) ms = es
     if (es > 1.0e-10_c_double) n10 = n10 + 1
  end do
  if (ms > 1.0e-14_c_double .or. n10 /= 0) then
     print *, "FAIL scalar accuracy", ms, n10
     stop 3
  end if

  qnan = transfer(int(z'7FF8000000000001', 8), qnan)
  pinf = transfer(int(z'7FF0000000000000', 8), pinf)
  if (pure_dsin(qnan) == pure_dsin(qnan)) stop 4
  if (pure_dsin(pinf) == pure_dsin(pinf)) stop 5
  if (pure_dsin(-pinf) == pure_dsin(-pinf)) stop 6
  if (pure_dcos(qnan) == pure_dcos(qnan)) stop 7

  xs = [0.1_c_double, qnan, 0.2_c_double, pinf]
  call pure_dsin_v(4, xs, ys4)
  if (ys4(2) == ys4(2) .or. ys4(4) == ys4(4)) then
     print *, "FAIL bulk specials", ys4
     stop 8
  end if

  print *, "PASS test_pure_bulk_abi max_abs_host=", ms
end program
