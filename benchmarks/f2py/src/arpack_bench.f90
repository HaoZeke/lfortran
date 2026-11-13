subroutine bench_dsaupd(n, nev, evals, info, niter)
  implicit none
  integer, intent(in) :: n, nev
  double precision, intent(out) :: evals(nev)
  integer, intent(out) :: info, niter
  integer, parameter :: ncv = 30
  integer :: ido, i, lworkl, ldv, ierr
  integer :: iparam(11), ipntr(14)
  double precision :: tol, sigma
  double precision :: resid(n), v(n, ncv), workd(3 * n)
  double precision :: workl(ncv * (ncv + 8)), d(nev), z(n, nev)
  logical :: rvec, select(ncv)
  character(len=1) :: bmat
  character(len=2) :: which
  integer :: logfil, ndigit, mgetv0
  integer :: msaupd, msaup2, msaitr, mseigt, msapps, msgets, mseupd
  integer :: mnaupd, mnaup2, mnaitr, mneigh, mnapps, mngets, mneupd
  integer :: mcaupd, mcaup2, mcaitr, mceigh, mcapps, mcgets, mceupd
  common /debug/ &
      logfil, ndigit, mgetv0, &
      msaupd, msaup2, msaitr, mseigt, msapps, msgets, mseupd, &
      mnaupd, mnaup2, mnaitr, mneigh, mnapps, mngets, mneupd, &
      mcaupd, mcaup2, mcaitr, mceigh, mcapps, mcgets, mceupd
  interface
    subroutine dsaupd(ido, bmat, n, which, nev, tol, resid, ncv, v, ldv, &
        iparam, ipntr, workd, workl, lworkl, info)
      integer :: ido, n, nev, ncv, ldv, lworkl, info
      character(len=1) :: bmat
      character(len=2) :: which
      double precision :: tol
      double precision :: resid(*), v(ldv, *), workd(*), workl(*)
      integer :: iparam(*), ipntr(*)
    end subroutine dsaupd
    subroutine dseupd(rvec, howmny, select, d, z, ldz, sigma, bmat, n, &
        which, nev, tol, resid, ncv, v, ldv, iparam, ipntr, workd, &
        workl, lworkl, info)
      logical :: rvec
      character(len=1) :: howmny, bmat
      character(len=2) :: which
      logical :: select(*)
      integer :: ldz, n, nev, ncv, ldv, lworkl, info
      double precision :: sigma, tol
      double precision :: d(*), z(ldz, *), resid(*), v(ldv, *)
      double precision :: workd(*), workl(*)
      integer :: iparam(*), ipntr(*)
    end subroutine dseupd
  end interface
  logfil = 6
  ndigit = 0
  mgetv0 = 0
  msaupd = 0
  msaup2 = 0
  msaitr = 0
  mseigt = 0
  msapps = 0
  msgets = 0
  mseupd = 0
  mnaupd = 0
  mnaup2 = 0
  mnaitr = 0
  mneigh = 0
  mnapps = 0
  mngets = 0
  mneupd = 0
  mcaupd = 0
  mcaup2 = 0
  mcaitr = 0
  mceigh = 0
  mcapps = 0
  mcgets = 0
  mceupd = 0
  ldv = n
  lworkl = ncv * (ncv + 8)
  tol = 0.0d0
  bmat = 'I'
  which = 'SA'
  ido = 0
  info = 1
  do i = 1, n
    resid(i) = sin(dble(i))
  end do
  do i = 1, 11
    iparam(i) = 0
    ipntr(i) = 0
  end do
  iparam(1) = 1
  ! Smallest eigenvalues of this Laplacian need several hundred restarts.
  iparam(3) = 2000
  iparam(4) = 1
  iparam(7) = 1
  do i = 1, nev
    evals(i) = 0.0d0
  end do
  niter = 0
  do i = 1, 100000
    call dsaupd(ido, bmat, n, which, nev, tol, resid, ncv, v, ldv, &
        iparam, ipntr, workd, workl, lworkl, info)
    if (ido == -1 .or. ido == 1) then
      call apply_laplacian(n, workd, ipntr(1), ipntr(2))
    else if (ido == 2) then
      call copy_vec(n, workd, ipntr(1), ipntr(2))
    else
      exit
    end if
  end do
  niter = iparam(3)
  if (info /= 0) return
  rvec = .false.
  sigma = 0.0d0
  call dseupd(rvec, 'A', select, d, z, ldv, sigma, bmat, n, which, &
      nev, tol, resid, ncv, v, ldv, iparam, ipntr, workd, workl, &
      lworkl, ierr)
  if (ierr /= 0) then
    info = ierr
    return
  end if
  do i = 1, nev
    evals(i) = d(i)
  end do
  info = 0
end subroutine bench_dsaupd

subroutine apply_laplacian(n, workd, ix, iy)
  implicit none
  integer :: n, ix, iy
  double precision :: workd(*)
  integer :: i
  workd(iy) = 2.0d0 * workd(ix) - workd(ix + 1)
  do i = 1, n - 2
    workd(iy + i) = -workd(ix + i - 1) + 2.0d0 * workd(ix + i) - workd(ix + i + 1)
  end do
  workd(iy + n - 1) = -workd(ix + n - 2) + 2.0d0 * workd(ix + n - 1)
end subroutine apply_laplacian

subroutine copy_vec(n, workd, ix, iy)
  implicit none
  integer :: n, ix, iy
  double precision :: workd(*)
  integer :: i
  do i = 0, n - 1
    workd(iy + i) = workd(ix + i)
  end do
end subroutine copy_vec
