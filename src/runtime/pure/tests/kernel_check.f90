! Kernel-interval checks on [-pi/2, pi/2] vs host intrinsics.
program kernel_check
  use, intrinsic :: iso_fortran_env, only: dp => real64
  use lfortran_intrinsic_trig, only: psin => sin, pcos => cos
  implicit none
  intrinsic :: sin, cos
  real(dp), parameter :: pi = 3.1415926535897932384626433832795_dp
  real(dp) :: x, e_s, e_c, max_s, max_c
  integer :: i, n
  n = 2000
  max_s = 0.0_dp
  max_c = 0.0_dp
  do i = 0, n
     x = -pi/2 + real(i, dp) * (pi / real(n, dp))
     e_s = abs(psin(x) - sin(x))
     e_c = abs(pcos(x) - cos(x))
     if (e_s > max_s) max_s = e_s
     if (e_c > max_c) max_c = e_c
  end do
  print *, "kernel_interval max_abs sin=", max_s, " cos=", max_c
  if (max_s > 5.0e-15_dp .or. max_c > 5.0e-15_dp) then
     print *, "FAIL: kernel abs error above 5e-15 on [-pi/2,pi/2]"
     stop 1
  end if
  print *, "PASS"
end program
