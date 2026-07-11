! Default path smoke: host sin/cos (libm via gfortran or LFortran default).
program libm_smoke
  use, intrinsic :: iso_fortran_env, only: dp => real64
  implicit none
  real(dp) :: x
  x = 1.5_dp
  print *, "math_backend=libm (host)"
  print *, "sin(1.5)=", sin(x), " cos(1.5)=", cos(x)
end program
