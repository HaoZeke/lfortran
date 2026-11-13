subroutine rosenbrock(x, f, g)
  implicit none
  double precision, intent(in) :: x(2)
  double precision, intent(out) :: f, g(3)
  double precision :: a, b
  a = x(2) - x(1) * x(1)
  b = 1.0d0 - x(1)
  f = 100.0d0 * a * a + b * b
  g(1) = -400.0d0 * x(1) * a - 2.0d0 * b
  g(2) = 200.0d0 * a
  g(3) = 0.0d0
end subroutine rosenbrock

subroutine bench_slsqp(nrep, mode_out, nfev, xmax)
  implicit none
  integer, intent(in) :: nrep
  integer, intent(out) :: mode_out, nfev
  double precision, intent(out) :: xmax
  integer, parameter :: n = 2, m = 0, meq = 0, la = 1
  integer, parameter :: lw = 400, ljw = 40
  integer :: rep, iter, mode, l_w, l_jw
  integer :: jw(ljw)
  integer :: iexact, incons, ireset, itermx, line, n1, n2, n3
  double precision :: x(n), xl(n), xu(n), f, c(la), g(n + 1), a(la, n + 1)
  double precision :: acc, w(lw)
  double precision :: alpha, f0, gs, h1, h2, h3, h4, t, t0, tol, err
  external slsqp
  nfev = 0
  xmax = 0.0d0
  mode_out = 0
  l_w = lw
  l_jw = ljw
  do rep = 1, nrep
    x(1) = -1.2d0
    x(2) = 1.0d0
    xl(1) = -1.0d6
    xl(2) = -1.0d6
    xu(1) = 1.0d6
    xu(2) = 1.0d6
    f = 0.0d0
    c(1) = 0.0d0
    g = 0.0d0
    a = 0.0d0
    w = 0.0d0
    jw = 0
    acc = 1.0d-12
    iter = 80
    mode = 0
    call rosenbrock(x, f, g)
    nfev = nfev + 1
    do
      call slsqp(m, meq, la, n, x, xl, xu, f, c, g, a, acc, iter, mode, &
          w, l_w, jw, l_jw, alpha, f0, gs, h1, h2, h3, h4, t, t0, tol, &
          iexact, incons, ireset, itermx, line, n1, n2, n3)
      if (mode == 1 .or. mode == -1) then
        call rosenbrock(x, f, g)
        nfev = nfev + 1
      else
        exit
      end if
    end do
    if (mode /= 0) then
      mode_out = mode
      xmax = max(abs(x(1) - 1.0d0), abs(x(2) - 1.0d0))
      return
    end if
    err = max(abs(x(1) - 1.0d0), abs(x(2) - 1.0d0))
    if (err > xmax) xmax = err
  end do
end subroutine bench_slsqp
