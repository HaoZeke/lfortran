! Absolute-ish accuracy: pure ABI vs real128 host sin on [-20,20].
! Label: not MPFR; real128 is higher precision than real64.
program test_pure_accuracy_r128
  use iso_c_binding
  use iso_fortran_env, only: real128
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
  integer, parameter :: n_grid = 4001
  integer :: i, n15s, n15c, n10s, n10c
  real(c_double) :: x, ps, pc, ms, mc, es, ec
  real(real128) :: xref, sref, cref

  ms = 0; mc = 0; n15s = 0; n15c = 0; n10s = 0; n10c = 0
  do i = 0, n_grid - 1
     x = -20.0_c_double + 40.0_c_double * real(i, c_double) / real(n_grid - 1, c_double)
     xref = real(x, real128)
     sref = sin(xref)
     cref = cos(xref)
     ps = pure_dsin(x)
     pc = pure_dcos(x)
     es = abs(ps - real(sref, c_double))
     ec = abs(pc - real(cref, c_double))
     if (es > ms) ms = es
     if (ec > mc) mc = ec
     if (es > 1.0d-15) n15s = n15s + 1
     if (ec > 1.0d-15) n15c = n15c + 1
     if (es > 1.0d-10) n10s = n10s + 1
     if (ec > 1.0d-10) n10c = n10c + 1
  end do
  print *, "ACCURACY_vs_real128 max_sin=", ms, " max_cos=", mc
  print *, "n_gt_1e-15 ", n15s, n15c, " n_gt_1e-10 ", n10s, n10c
  if (n10s /= 0 .or. n10c /= 0) then
     print *, "FAIL n>1e-10 non-zero vs real128"
     stop 1
  end if
  print *, "PASS test_pure_accuracy_r128"
end program
