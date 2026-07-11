! Production-shaped: link liblfortran_runtime_pure_math.a, call pure ABI only.
program test_pure_archive_abi
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
  end interface
  real(c_double) :: x, ps, hs, err, maxerr
  integer :: i, nbad
  maxerr = 0
  nbad = 0
  do i = 0, 4000
     x = -20.0_c_double + 40.0_c_double * real(i, c_double) / 4000.0_c_double
     ps = pure_dsin(x)
     hs = host_sin(x)
     err = abs(ps - hs)
     if (err > maxerr) maxerr = err
     if (err > 1.0e-10_c_double) nbad = nbad + 1
  end do
  if (nbad /= 0) then
     print *, "FAIL nbad=", nbad, " maxerr=", maxerr
     stop 1
  end if
  if (maxerr > 1.0e-14_c_double) then
     print *, "FAIL maxerr too large:", maxerr
     stop 2
  end if
  ! principal band smoke
  if (abs(pure_dsin(1.0_c_double) - host_sin(1.0_c_double)) > 1.0e-15_c_double) then
     print *, "FAIL principal band"
     stop 3
  end if
  print *, "PASS test_pure_archive_abi maxerr=", maxerr
end program
