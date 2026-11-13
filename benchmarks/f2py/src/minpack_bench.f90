subroutine lmdif_fcn(m, n, x, fvec, iflag)
  implicit none
  integer :: m, n, iflag
  double precision :: x(n), fvec(m)
  integer, parameter :: mmax = 20000
  integer :: msave, i
  double precision :: t(mmax), yobs(mmax), ti
  common /lmdifd/ msave, t, yobs
  do i = 1, m
    ti = t(i)
    fvec(i) = x(1) * exp(-x(2) * ti) + x(3) * exp(-x(4) * ti) - yobs(i)
  end do
end subroutine lmdif_fcn

subroutine bench_lmdif(m, x, info, nfev, ssq)
  implicit none
  integer, intent(in) :: m
  double precision, intent(inout) :: x(4)
  integer, intent(out) :: info, nfev
  double precision, intent(out) :: ssq
  integer, parameter :: n = 4
  integer, parameter :: mmax = 20000
  integer :: msave, i, mode, nprint, maxfev, ldfjac
  double precision :: t(mmax), yobs(mmax)
  double precision :: ftol, xtol, gtol, epsfcn, factor
  double precision :: fvec(mmax), diag(n), qtf(n)
  double precision :: wa1(n), wa2(n), wa3(n), wa4(mmax)
  double precision :: fjac(mmax, n)
  integer :: ipvt(n)
  common /lmdifd/ msave, t, yobs
  external lmdif_fcn
  interface
    subroutine lmdif(fcn, m, n, x, fvec, ftol, xtol, gtol, maxfev, epsfcn, &
        diag, mode, factor, nprint, info, nfev, fjac, ldfjac, &
        ipvt, qtf, wa1, wa2, wa3, wa4)
      external fcn
      integer :: m, n, maxfev, mode, nprint, info, nfev, ldfjac
      double precision :: ftol, xtol, gtol, epsfcn, factor
      double precision :: x(*), fvec(*), diag(*), qtf(*)
      double precision :: wa1(*), wa2(*), wa3(*), wa4(*)
      double precision :: fjac(ldfjac, *)
      integer :: ipvt(*)
    end subroutine lmdif
  end interface
  if (m > mmax) then
    info = -1
    nfev = 0
    ssq = -1.0d0
    return
  end if
  msave = m
  do i = 1, m
    t(i) = dble(i) / dble(m)
    yobs(i) = 2.0d0 * exp(-0.5d0 * t(i)) + 0.5d0 * exp(-3.0d0 * t(i))
  end do
  ftol = 1.0d-12
  xtol = 1.0d-12
  gtol = 0.0d0
  epsfcn = 0.0d0
  mode = 1
  factor = 100.0d0
  nprint = 0
  maxfev = 2000
  ldfjac = mmax
  diag(1) = 1.0d0
  diag(2) = 1.0d0
  diag(3) = 1.0d0
  diag(4) = 1.0d0
  call lmdif(lmdif_fcn, m, n, x, fvec, ftol, xtol, gtol, maxfev, epsfcn, &
      diag, mode, factor, nprint, info, nfev, fjac, ldfjac, &
      ipvt, qtf, wa1, wa2, wa3, wa4)
  ssq = 0.0d0
  do i = 1, m
    ssq = ssq + fvec(i) * fvec(i)
  end do
end subroutine bench_lmdif

subroutine powell_fcn(n, x, fvec, iflag)
  implicit none
  integer :: n, iflag
  double precision :: x(n), fvec(n)
  integer :: nfev
  common /hybrdd/ nfev
  nfev = nfev + 1
  fvec(1) = x(1) + 10.0d0 * x(2)
  fvec(2) = sqrt(5.0d0) * (x(3) - x(4))
  fvec(3) = (x(2) - 2.0d0 * x(3))**2
  fvec(4) = sqrt(10.0d0) * (x(1) - x(4))**2
end subroutine powell_fcn

subroutine bench_hybrd(nrep, info, nfev_out, xmax)
  implicit none
  integer, intent(in) :: nrep
  integer, intent(out) :: info, nfev_out
  double precision, intent(out) :: xmax
  integer, parameter :: n = 4
  integer, parameter :: lwa = (n * (3 * n + 13)) / 2
  integer :: rep, nfev, i
  double precision :: x(n), fvec(n), wa(lwa), tol, ax, xsum
  common /hybrdd/ nfev
  external powell_fcn
  interface
    subroutine hybrd1(fcn, n, x, fvec, tol, info, wa, lwa)
      integer :: n, info, lwa
      double precision :: tol
      double precision :: x(*), fvec(*), wa(*)
      external fcn
    end subroutine hybrd1
  end interface
  tol = 1.0d-10
  info = 0
  nfev_out = 0
  xmax = -1.0d0
  xsum = 0.0d0
  do rep = 1, nrep
    x(1) = 3.0d0
    x(2) = -1.0d0
    x(3) = 0.0d0
    x(4) = 1.0d0
    nfev = 0
    call hybrd1(powell_fcn, n, x, fvec, tol, info, wa, lwa)
    xsum = xsum + x(1) + x(2) + x(3) + x(4)
    if (info /= 1 .and. info /= 4) exit
  end do
  nfev_out = nfev
  xmax = abs(xsum)
  do i = 1, n
    ax = abs(x(i))
    if (ax > xmax) xmax = ax
  end do
end subroutine bench_hybrd
