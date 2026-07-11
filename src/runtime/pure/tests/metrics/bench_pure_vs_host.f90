! Metrics: pure Sollya kernels (via bind(c) ABI) vs host sin/cos.
! Linked with -llfortran_runtime_pure_math (same archive as --math-backend=pure).
program bench_pure_vs_host
  use, intrinsic :: iso_c_binding, only: c_double
  use, intrinsic :: iso_fortran_env, only: dp => real64, int64
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
  real(dp), parameter :: x_lo = -20.0_dp, x_hi = 20.0_dp
  real(dp) :: step, x, es, ec, hs, hc, ps, pc
  real(dp) :: max_s, max_c, sum_s, sum_c, mean_s, mean_c
  real(dp) :: p50_s, p95_s, p99_s, p50_c, p95_c, p99_c
  real(dp), allocatable :: errs_s(:), errs_c(:)
  integer :: i, n_gt_1e10_s, n_gt_1e15_s, n_gt_1e10_c, n_gt_1e15_c
  integer :: n_time, w
  real(dp) :: t0, t1, t2, t3, acc
  integer(int64) :: n_ops
  character(len=256) :: out_prefix

  call get_command_argument(1, out_prefix)
  if (len_trim(out_prefix) == 0) out_prefix = "metrics_out"

  allocate(errs_s(n_grid), errs_c(n_grid))
  step = (x_hi - x_lo) / real(n_grid - 1, dp)
  max_s = 0; max_c = 0; sum_s = 0; sum_c = 0
  n_gt_1e10_s = 0; n_gt_1e15_s = 0
  n_gt_1e10_c = 0; n_gt_1e15_c = 0

  open(20, file=trim(out_prefix)//"_sin_err.dat")
  open(21, file=trim(out_prefix)//"_cos_err.dat")
  do i = 1, n_grid
     x = x_lo + real(i - 1, dp) * step
     hs = sin(x); hc = cos(x)
     ps = pure_dsin(x); pc = pure_dcos(x)
     es = abs(ps - hs); ec = abs(pc - hc)
     errs_s(i) = es; errs_c(i) = ec
     if (es > max_s) max_s = es
     if (ec > max_c) max_c = ec
     sum_s = sum_s + es; sum_c = sum_c + ec
     if (es > 1.0e-10_dp) n_gt_1e10_s = n_gt_1e10_s + 1
     if (es > 1.0e-15_dp) n_gt_1e15_s = n_gt_1e15_s + 1
     if (ec > 1.0e-10_dp) n_gt_1e10_c = n_gt_1e10_c + 1
     if (ec > 1.0e-15_dp) n_gt_1e15_c = n_gt_1e15_c + 1
     write(20, *) x, es
     write(21, *) x, ec
  end do
  close(20); close(21)
  mean_s = sum_s / real(n_grid, dp)
  mean_c = sum_c / real(n_grid, dp)
  call percentile(errs_s, 50.0_dp, p50_s)
  call percentile(errs_s, 95.0_dp, p95_s)
  call percentile(errs_s, 99.0_dp, p99_s)
  call percentile(errs_c, 50.0_dp, p50_c)
  call percentile(errs_c, 95.0_dp, p95_c)
  call percentile(errs_c, 99.0_dp, p99_c)

  open(30, file=trim(out_prefix)//"_accuracy.txt")
  write(30, '(a)') "metric sin cos"
  write(30, '(a,2es16.8)') "max_abs ", max_s, max_c
  write(30, '(a,2es16.8)') "mean_abs ", mean_s, mean_c
  write(30, '(a,2es16.8)') "p50_abs ", p50_s, p50_c
  write(30, '(a,2es16.8)') "p95_abs ", p95_s, p95_c
  write(30, '(a,2es16.8)') "p99_abs ", p99_s, p99_c
  write(30, '(a,2i10)') "n_gt_1e-15 ", n_gt_1e15_s, n_gt_1e15_c
  write(30, '(a,2i10)') "n_gt_1e-10 ", n_gt_1e10_s, n_gt_1e10_c
  write(30, '(a,i10)') "n_grid ", n_grid
  write(30, '(a,2f12.4)') "range ", x_lo, x_hi
  close(30)

  ! Timing: large N, warmup, host then pure then host again (ordering bias check)
  n_time = 5000000
  n_ops = int(n_time, int64)
  ! warmup
  acc = 0
  do i = 1, 100000
     x = 1.0e-6_dp * real(i, dp)
     acc = acc + pure_dsin(x) + sin(x)
  end do
  if (acc == -999.0_dp) print *, acc  ! prevent DCE

  acc = 0
  call cpu_time(t0)
  do i = 1, n_time
     x = 1.0e-6_dp * real(i, dp)
     acc = acc + pure_dsin(x)
  end do
  call cpu_time(t1)
  do i = 1, n_time
     x = 1.0e-6_dp * real(i, dp)
     acc = acc + sin(x)
  end do
  call cpu_time(t2)
  do i = 1, n_time
     x = 1.0e-6_dp * real(i, dp)
     acc = acc + pure_dsin(x)
  end do
  call cpu_time(t3)
  if (acc == -999.0_dp) print *, acc

  open(31, file=trim(out_prefix)//"_timing.txt")
  write(31, '(a)') "path seconds n_calls ns_per_call mcalls_per_s"
  write(31, '(a,es16.8,i12,es16.8,es16.8)') "pure_first ", t1-t0, n_time, &
       1.0e9_dp*(t1-t0)/real(n_time,dp), real(n_time,dp)/(t1-t0)/1.0e6_dp
  write(31, '(a,es16.8,i12,es16.8,es16.8)') "host ", t2-t1, n_time, &
       1.0e9_dp*(t2-t1)/real(n_time,dp), real(n_time,dp)/(t2-t1)/1.0e6_dp
  write(31, '(a,es16.8,i12,es16.8,es16.8)') "pure_second ", t3-t2, n_time, &
       1.0e9_dp*(t3-t2)/real(n_time,dp), real(n_time,dp)/(t3-t2)/1.0e6_dp
  write(31, '(a,es16.8)') "ratio_pure_over_host_mean ", &
       0.5_dp*((t1-t0)+(t3-t2))/(t2-t1)
  close(31)

  print *, "ACCURACY max_abs sin=", max_s, " cos=", max_c
  print *, "ACCURACY n_gt_1e-10 sin=", n_gt_1e10_s, " cos=", n_gt_1e10_c
  print *, "TIMING pure_s=", 0.5_dp*((t1-t0)+(t3-t2)), " host_s=", (t2-t1), &
       " ratio_pure/host=", 0.5_dp*((t1-t0)+(t3-t2))/(t2-t1)
  print *, "WROTE ", trim(out_prefix), "_accuracy.txt timing.txt *err.dat"

contains
  subroutine percentile(a, pct, val)
    real(dp), intent(in) :: a(:), pct
    real(dp), intent(out) :: val
    real(dp), allocatable :: b(:)
    integer :: n, k
    n = size(a)
    allocate(b(n))
    b = a
    call sort_asc(b)
    k = max(1, min(n, int(ceiling(pct/100.0_dp * real(n, dp)))))
    val = b(k)
  end subroutine

  subroutine sort_asc(a)
    real(dp), intent(inout) :: a(:)
    integer :: n, i, j
    real(dp) :: t
    n = size(a)
    ! insertion sort OK for 4k
    do i = 2, n
       t = a(i)
       j = i - 1
       do while (j >= 1)
          if (a(j) <= t) exit
          a(j+1) = a(j)
          j = j - 1
       end do
       a(j+1) = t
    end do
  end subroutine
end program
