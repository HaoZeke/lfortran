subroutine cobyla_fc(n, m, x, f, con)
  implicit none
  integer :: n, m
  double precision :: x(n), f, con(m)
  f = (x(1) - 1.5d0)**2 + (x(2) - 0.5d0)**2
  con(1) = 1.0d0 - x(1) * x(1) - x(2) * x(2)
end subroutine cobyla_fc

subroutine cobyla_cb(n, m, x)
  implicit none
  integer :: n, m
  double precision :: x(n)
end subroutine cobyla_cb

subroutine bench_cobyla(nrep, info, nfev, xmax)
  implicit none
  integer, intent(in) :: nrep
  integer, intent(out) :: info, nfev
  double precision, intent(out) :: xmax
  integer, parameter :: n = 2, m = 1
  integer, parameter :: lw = n * (3 * n + 2 * m + 11) + 4 * m + 6
  integer :: rep, iprint, maxfun, iact(m + 1)
  double precision :: x(n), w(lw), dinfo(4), err, scale
  double precision :: xs, ys
  external cobyla, cobyla_fc, cobyla_cb
  nfev = 0
  xmax = 0.0d0
  info = 0
  scale = sqrt(2.5d0)
  xs = 1.5d0 / scale
  ys = 0.5d0 / scale
  iprint = 0
  do rep = 1, nrep
    x(1) = 0.0d0
    x(2) = 0.0d0
    w = 0.0d0
    iact = 0
    dinfo = 0.0d0
    maxfun = 200
    call cobyla(cobyla_fc, n, m, x, 0.5d0, 1.0d-8, iprint, maxfun, &
        w, iact, dinfo, cobyla_cb)
    nfev = nfev + maxfun
    if (dinfo(1) /= 1.0d0) then
      info = int(dinfo(1))
      xmax = max(abs(x(1) - xs), abs(x(2) - ys))
      return
    end if
    err = max(abs(x(1) - xs), abs(x(2) - ys))
    if (err > xmax) xmax = err
  end do
end subroutine bench_cobyla
