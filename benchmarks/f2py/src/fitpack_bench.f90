subroutine bench_splrep(m, x, y, w, nest, t, c, lwrk, wrk, iwrk, n, fp, ier)
  implicit none
  integer, intent(in) :: m, nest, lwrk
  double precision, intent(in) :: x(m), y(m), w(m)
  double precision, intent(inout) :: t(nest), c(nest), wrk(lwrk)
  integer, intent(inout) :: iwrk(nest)
  integer, intent(out) :: n, ier
  double precision, intent(out) :: fp
  integer :: k, iopt
  double precision :: xb, xe, s
  interface
    subroutine curfit(iopt, m, x, y, w, xb, xe, k, s, nest, n, &
        t, c, fp, wrk, lwrk, iwrk, ier)
      integer :: iopt, m, k, nest, n, lwrk, ier
      double precision :: xb, xe, s, fp
      double precision :: x(*), y(*), w(*), t(*), c(*), wrk(*)
      integer :: iwrk(*)
    end subroutine curfit
  end interface
  k = 3
  iopt = 0
  s = 0.0d0
  xb = x(1)
  xe = x(m)
  n = 0
  call curfit(iopt, m, x, y, w, xb, xe, k, s, nest, n, &
      t, c, fp, wrk, lwrk, iwrk, ier)
end subroutine bench_splrep

subroutine bench_splev(n, t, c, k, m, x, y, ier)
  implicit none
  integer, intent(in) :: n, k, m
  double precision, intent(in) :: t(n), c(n), x(m)
  double precision, intent(out) :: y(m)
  integer, intent(out) :: ier
  integer :: nc
  interface
    subroutine splev(t, n, c, nc, k, x, y, m, e, ier)
      integer :: n, nc, k, m, e, ier
      double precision :: t(*), c(*), x(*), y(*)
    end subroutine splev
  end interface
  nc = n - k - 1
  call splev(t, n, c, nc, k, x, y, m, 0, ier)
end subroutine bench_splev
