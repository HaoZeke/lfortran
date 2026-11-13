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
