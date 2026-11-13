subroutine odr_fcn(n, m, np, nq, ldn, ldm, ldnp, beta, xplusd, &
    ifixb, ifixx, ldifx, ideval, f, fjacb, fjacd, istop)
  implicit none
  integer :: n, m, np, nq, ldn, ldm, ldnp, ldifx, ideval, istop
  integer :: ifixb(*), ifixx(ldifx, *)
  double precision :: beta(*), xplusd(ldn, *), f(ldn, *)
  double precision :: fjacb(ldn, ldnp, *), fjacd(ldn, ldm, *)
  integer :: nfev
  integer :: i
  common /odrcnt/ nfev
  istop = 0
  ! Units digit requests the residual. y = b1 + b2 * x.
  if (mod(ideval, 10) >= 1) then
    nfev = nfev + 1
    do i = 1, n
      f(i, 1) = beta(1) + beta(2) * xplusd(i, 1)
    end do
  end if
  if (mod(ideval / 10, 10) >= 1) then
    do i = 1, n
      fjacb(i, 1, 1) = 1.0d0
      fjacb(i, 2, 1) = xplusd(i, 1)
    end do
  end if
  if (mod(ideval / 100, 10) >= 1) then
    do i = 1, n
      fjacd(i, 1, 1) = beta(2)
    end do
  end if
end subroutine odr_fcn

subroutine bench_odr(nrep, info, nfev, b1, b2)
  implicit none
  integer, intent(in) :: nrep
  integer, intent(out) :: info, nfev
  double precision, intent(out) :: b1, b2
  integer, parameter :: n = 48
  integer, parameter :: m = 1
  integer, parameter :: np = 2
  integer, parameter :: nq = 1
  integer, parameter :: lwork = 200000
  integer, parameter :: liwork = 20000
  integer :: rep, i
  integer :: job, iprint, lunerr, lunrpt
  double precision :: beta(np), y(n, nq), x(n, m)
  double precision :: we(1, 1, nq), wd(1, 1, m)
  double precision :: work(lwork)
  integer :: iwork(liwork)
  integer :: nfev_save
  common /odrcnt/ nfev_save
  external odr_fcn
  job = 0
  iprint = 0
  lunerr = 0
  lunrpt = 0
  ! A negative leading weight is the scalar default (unit weights).
  we(1, 1, 1) = -1.0d0
  wd(1, 1, 1) = -1.0d0
  do i = 1, n
    x(i, 1) = dble(i) / dble(n)
    y(i, 1) = 1.0d0 + 2.0d0 * x(i, 1)
  end do
  info = 0
  nfev = 0
  b1 = 0.0d0
  b2 = 0.0d0
  do rep = 1, nrep
    beta(1) = 0.0d0
    beta(2) = 0.0d0
    nfev_save = 0
    call dodr(odr_fcn, n, m, np, nq, beta, y, n, x, n, &
        we, 1, 1, wd, 1, 1, job, iprint, lunerr, lunrpt, &
        work, lwork, iwork, liwork, info)
    nfev = nfev + nfev_save
    if (info < 1 .or. info > 3) exit
  end do
  b1 = beta(1)
  b2 = beta(2)
end subroutine bench_odr
