! Metrics: pure Sollya sin/cos vs host with vectorization ON.
! Primary speed: array pure batch (dsin_v) and elemental vs host array-expr.
! Scalar same-loop pure vs host is the blog GSoC comparison.
program bench_simd
  use lfortran_intrinsic_trig, only: dsin, dcos, dsin_v
  use iso_c_binding
  implicit none
  interface
    subroutine pure_dsin_v(n, x, y) bind(c, name="_lfortran_pure_dsin_v")
      import :: c_int, c_double
      integer(c_int), value :: n
      real(c_double) :: x(n), y(n)
    end subroutine
    function pure_dsin(x) bind(c, name="_lfortran_pure_dsin") result(r)
      import :: c_double
      real(c_double), value :: x
      real(c_double) :: r
    end function
  end interface

  integer, parameter :: n = 1000000, reps = 200, n_grid = 4001
  integer, parameter :: n_scalar = 5000000
  real(8), allocatable :: x(:), yh(:), yp(:), yv(:)
  real(8) :: t0, t1, t2, t3, t4, t5, t6, t7, dummy, xx, es, ec, ms, mc
  integer :: i, r, n10s, n10c, n15s, n15c
  character(len=256) :: prefix

  call get_command_argument(1, prefix)
  if (len_trim(prefix) == 0) prefix = "simd_out"

  allocate(x(n), yh(n), yp(n), yv(n))
  do i = 1, n
     x(i) = -1.5d0 + 3.0d0 * real(i - 1, 8) / real(n - 1, 8)
  end do

  ms = 0; mc = 0; n10s = 0; n10c = 0; n15s = 0; n15c = 0
  open(20, file=trim(prefix)//"_sin_err.dat")
  open(21, file=trim(prefix)//"_cos_err.dat")
  do i = 0, n_grid - 1
     xx = -20.0d0 + 40.0d0 * real(i, 8) / real(n_grid - 1, 8)
     es = abs(dsin(xx) - sin(xx))
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
  close(30)

  dummy = 0
  do i = 1, min(n, 10000)
     dummy = dummy + dsin(x(i)) + sin(x(i))
  end do
  yh = sin(x)
  call dsin_v(x, yv)
  yp = dsin(x)
  if (dummy == -1.0d0) print *, dummy

  ! Scalar same-loop
  dummy = 0
  call cpu_time(t0)
  do i = 1, n_scalar
     xx = 1.5d0 * real(i, 8) / real(n_scalar, 8)
     dummy = dummy + dsin(xx)
  end do
  call cpu_time(t1)
  do i = 1, n_scalar
     xx = 1.5d0 * real(i, 8) / real(n_scalar, 8)
     dummy = dummy + sin(xx)
  end do
  call cpu_time(t2)
  do i = 1, n_scalar
     xx = 1.5d0 * real(i, 8) / real(n_scalar, 8)
     dummy = dummy + pure_dsin(xx)
  end do
  call cpu_time(t3)
  if (dummy == -1.0d0) print *, dummy

  ! Array
  call cpu_time(t4)
  do r = 1, reps
     yh = sin(x)
  end do
  call cpu_time(t5)
  do r = 1, reps
     call dsin_v(x, yv)
  end do
  call cpu_time(t6)
  do r = 1, reps
     yp = dsin(x)
  end do
  call cpu_time(t7)

  open(31, file=trim(prefix)//"_timing.txt")
  write(31, '(a)') "path seconds notes"
  write(31, '(a,es16.8,a)') "pure_scalar_loop ", (t1 - t0), " dsin_same_loop"
  write(31, '(a,es16.8,a)') "host_scalar_loop ", (t2 - t1), " sin_same_loop"
  write(31, '(a,es16.8)') "ratio_pure_scalar_loop_over_host ", (t1 - t0) / (t2 - t1)
  write(31, '(a,es16.8,a)') "pure_bindc_scalar ", (t3 - t2), " pure_dsin"
  write(31, '(a,es16.8)') "ratio_pure_bindc_over_host_scalar ", (t3 - t2) / (t2 - t1)
  write(31, '(a,es16.8,a)') "host_array_expr ", (t5 - t4), " libmvec_possible"
  write(31, '(a,es16.8,a)') "pure_omp_simd_dsin_v ", (t6 - t5), " dsin_v_autovec"
  write(31, '(a,es16.8,a)') "pure_elemental_array ", (t7 - t6), " yp=dsin(x)"
  write(31, '(a,es16.8)') "ratio_pure_simd_v_over_host_array ", (t6 - t5) / (t5 - t4)
  write(31, '(a,es16.8)') "ratio_pure_elem_array_over_host_array ", (t7 - t6) / (t5 - t4)
  write(31, '(a,es16.8)') "max_abs_err_array ", maxval(abs(yv - yh))
  close(31)

  print *, "ACCURACY max_sin=", ms, " max_cos=", mc, " n10=", n10s, n10c, " n15=", n15s, n15c
  print *, "SCALAR_LOOP pure=", t1-t0, " host=", t2-t1, " ratio=", (t1-t0)/(t2-t1)
  print *, "BINDC pure=", t3-t2, " ratio=", (t3-t2)/(t2-t1)
  print *, "ARRAY host=", t5-t4, " dsin_v=", t6-t5, " ratio=", (t6-t5)/(t5-t4)
  print *, "ARRAY elemental=", t7-t6, " ratio=", (t7-t6)/(t5-t4)
  print *, "max_array_err=", maxval(abs(yv-yh))
end program
