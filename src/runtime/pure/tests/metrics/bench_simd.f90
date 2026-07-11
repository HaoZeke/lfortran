! Production-shaped pure metrics.
! Scalar: external pure ABI vs external host libm sin (both bind(c)).
! Array-LFortran-shape: loop of pure_dsin calls (what LFortran emits for y=sin(x)).
! Array-gfortran-module: yp=dsin(x) labeled separately (not LFortran production).
program bench_simd
  use iso_c_binding
  use lfortran_intrinsic_trig, only: dsin, dcos
  implicit none
  interface
    function pure_dsin(x) bind(c, name="_lfortran_pure_dsin") result(r)
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

  integer, parameter :: n = 1000000, reps = 50, n_grid = 4001
  integer, parameter :: n_scalar = 5000000
  real(8), allocatable :: x(:), yh(:), yp(:), yl(:)
  real(8) :: t0, t1, t2, t3, t4, t5, t6, t7, dummy, xx, es, ec, ms, mc
  real(8) :: pure_s, host_s
  integer :: i, r, n10s, n10c, n15s, n15c
  character(len=256) :: prefix

  call get_command_argument(1, prefix)
  if (len_trim(prefix) == 0) prefix = "simd_out"

  allocate(x(n), yh(n), yp(n), yl(n))
  do i = 1, n
     x(i) = -1.5d0 + 3.0d0 * real(i - 1, 8) / real(n - 1, 8)
  end do

  ms = 0; mc = 0; n10s = 0; n10c = 0; n15s = 0; n15c = 0
  open(20, file=trim(prefix)//"_sin_err.dat")
  open(21, file=trim(prefix)//"_cos_err.dat")
  do i = 0, n_grid - 1
     xx = -20.0d0 + 40.0d0 * real(i, 8) / real(n_grid - 1, 8)
     es = abs(pure_dsin(xx) - host_sin(xx))
     ec = abs(dcos(xx) - cos(xx))
     if (es > ms) ms = es
     if (ec > mc) mc = ec
     if (es > 1.0d-15) n15s = n15s + 1
     if (ec > 1.0d-15) n15c = n15c + 1
     if (es > 1.0d-10) n10s = n10s + 1
     if (ec > 1.0d-10) n10c = n10c + 1
     write(20, *) xx, es
     write(21, *) xx, ec
  end do
  close(20); close(21)

  open(30, file=trim(prefix)//"_accuracy.txt")
  write(30, '(a)') "metric sin cos"
  write(30, '(a,2es16.8)') "max_abs ", ms, mc
  write(30, '(a,2i10)') "n_gt_1e-15 ", n15s, n15c
  write(30, '(a,2i10)') "n_gt_1e-10 ", n10s, n10c
  write(30, '(a,i10)') "n_grid ", n_grid
  write(30, '(a)') "note accuracy_pure_ABI_vs_host_c_sin_for_sin"
  close(30)

  dummy = 0
  do i = 1, min(n, 10000)
     dummy = dummy + pure_dsin(x(i)) + host_sin(x(i)) + dsin(x(i))
  end do
  if (dummy == -1.0d0) print *, dummy

  ! Scalar: two pure runs, then host C ABI sin
  dummy = 0
  call cpu_time(t0)
  do i = 1, n_scalar
     xx = 1.5d0 * real(i, 8) / real(n_scalar, 8)
     dummy = dummy + pure_dsin(xx)
  end do
  call cpu_time(t1)
  do i = 1, n_scalar
     xx = 1.5d0 * real(i, 8) / real(n_scalar, 8)
     dummy = dummy + pure_dsin(xx)
  end do
  call cpu_time(t2)
  do i = 1, n_scalar
     xx = 1.5d0 * real(i, 8) / real(n_scalar, 8)
     dummy = dummy + host_sin(xx)
  end do
  call cpu_time(t3)
  pure_s = 0.5d0 * ((t1 - t0) + (t2 - t1))
  host_s = t3 - t2

  ! Array host expression (libmvec possible)
  call cpu_time(t4)
  do r = 1, reps
     yh = sin(x)
  end do
  call cpu_time(t5)
  ! LFortran-shaped: loop of external pure_dsin (production emission)
  do r = 1, reps
     do i = 1, n
        yl(i) = pure_dsin(x(i))
     end do
  end do
  call cpu_time(t6)
  ! gfortran pure module elemental (NOT LFortran production; reported separately)
  do r = 1, reps
     yp = dsin(x)
  end do
  call cpu_time(t7)
  if (dummy == -1.0d0) print *, dummy

  open(31, file=trim(prefix)//"_timing.txt")
  write(31, '(a)') "path seconds notes"
  write(31, '(a,es16.8,a)') "pure_bindc_scalar ", pure_s, " external_pure_ABI_mean2"
  write(31, '(a,es16.8,a)') "host_scalar_loop ", host_s, " external_c_sin"
  write(31, '(a,es16.8)') "ratio_pure_bindc_over_host_scalar ", pure_s / host_s
  write(31, '(a,es16.8)') "pure_ns_per_call ", pure_s * 1.0d9 / real(n_scalar, 8)
  write(31, '(a,es16.8)') "host_ns_per_call ", host_s * 1.0d9 / real(n_scalar, 8)
  write(31, '(a,es16.8,a)') "host_array_expr ", (t5 - t4), " yh=sin(x)_libmvec_possible"
  write(31, '(a,es16.8,a)') "pure_lfortran_shape_array ", (t6 - t5), " loop_pure_dsin_calls"
  write(31, '(a,es16.8)') "ratio_pure_lfortran_shape_over_host_array ", (t6 - t5) / (t5 - t4)
  write(31, '(a,es16.8,a)') "pure_gfortran_elemental_array ", (t7 - t6), " yp=dsin_NOT_lfortran"
  write(31, '(a,es16.8)') "ratio_pure_gfortran_elem_over_host_array ", (t7 - t6) / (t5 - t4)
  write(31, '(a,es16.8)') "max_abs_err_array_lfortran_shape ", maxval(abs(yl - yh))
  ! keys expected by run_metrics.py (primary = production shape)
  write(31, '(a,es16.8,a)') "pure_scalar_loop ", pure_s, " alias"
  write(31, '(a,es16.8)') "ratio_pure_scalar_loop_over_host ", pure_s / host_s
  write(31, '(a,es16.8,a)') "pure_elemental_array ", (t6 - t5), " alias_lfortran_shape"
  write(31, '(a,es16.8)') "ratio_pure_elem_array_over_host_array ", (t6 - t5) / (t5 - t4)
  write(31, '(a,es16.8,a)') "pure_omp_simd_dsin_v ", (t6 - t5), " alias_lfortran_shape"
  write(31, '(a,es16.8)') "ratio_pure_simd_v_over_host_array ", (t6 - t5) / (t5 - t4)
  close(31)

  print *, "ACCURACY pure_ABI_vs_c_sin max_sin=", ms, " max_cos=", mc, " n10=", n10s, n10c
  print *, "SCALAR pure_ns=", pure_s*1d9/n_scalar, " host_c_sin_ns=", host_s*1d9/n_scalar, &
       " ratio=", pure_s/host_s, " speedup=", host_s/pure_s
  print *, "ARRAY host_expr=", t5-t4, " lfortran_shape_loop_pure_dsin=", t6-t5, &
       " ratio=", (t6-t5)/(t5-t4)
  print *, "ARRAY gfortran_elem_dsin=", t7-t6, " ratio=", (t7-t6)/(t5-t4), &
       " (not LFortran production)"
  print *, "max_err_lfortran_shape=", maxval(abs(yl-yh))
end program
