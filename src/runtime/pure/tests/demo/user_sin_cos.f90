! User program for pure-math-backend demo (links pure ABI like --math-backend=pure).
program user_sin_cos
  use, intrinsic :: iso_c_binding, only: c_double
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
  end interface
  real(c_double) :: x, ps, pc, hs, hc
  integer :: i
  print *, "math_backend=pure (bind _lfortran_pure_d{sin,cos})"
  do i = 0, 8
     x = -1.5_c_double + 0.375_c_double * real(i, c_double)
     ps = pure_dsin(x)
     pc = pure_dcos(x)
     hs = sin(x)
     hc = cos(x)
     print "(a,f10.6,a,es12.4,a,es12.4)", "x=", x, "  |dsin|=", abs(ps-hs), "  |dcos|=", abs(pc-hc)
  end do
end program
