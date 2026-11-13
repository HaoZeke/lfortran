subroutine bench_mvndst(nrep, nfev, inform, err)
  implicit none
  integer, intent(in) :: nrep
  integer, intent(out) :: nfev, inform
  double precision, intent(out) :: err
  integer, parameter :: n = 5
  integer :: rep, i, maxpts, inf
  integer :: infin(n)
  double precision :: lower(n), upper(n), correl(n * (n - 1) / 2)
  double precision :: abseps, releps, error, value, worst
  external mvndst
  nfev = nrep
  inform = 0
  worst = 0.0d0
  do i = 1, n
    infin(i) = 0
    lower(i) = 0.0d0
    upper(i) = 0.0d0
  end do
  correl = 0.0d0
  maxpts = 20000
  abseps = 1.0d-6
  releps = 1.0d-6
  do rep = 1, nrep
    call mvndst(n, lower, upper, infin, correl, maxpts, abseps, releps, &
        error, value, inf)
    if (inf /= 0) inform = inf
    worst = max(worst, abs(value - 0.03125d0))
    worst = max(worst, error)
  end do
  err = worst
end subroutine bench_mvndst
