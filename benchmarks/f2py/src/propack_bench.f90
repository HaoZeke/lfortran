subroutine paprod(transa, m, n, x, y, dparm, iparm)
  implicit none
  character(len=1) :: transa
  integer :: m, n, iparm(*)
  double precision :: x(*), y(*), dparm(*)
  integer :: nmat
  integer :: i
  common /ppcnt/ nmat
  nmat = nmat + 1
  if (transa == 'N' .or. transa == 'n') then
    do i = 1, n
      y(i) = dparm(i) * x(i)
    end do
    do i = n + 1, m
      y(i) = 0.0d0
    end do
  else
    do i = 1, n
      y(i) = dparm(i) * x(i)
    end do
  end if
end subroutine paprod

subroutine bench_propack(nrep, info, nmat, sigma_err)
  implicit none
  integer, intent(in) :: nrep
  integer, intent(out) :: info, nmat
  double precision, intent(out) :: sigma_err
  integer, parameter :: m = 400
  integer, parameter :: n = 200
  integer, parameter :: k = 4
  integer, parameter :: kmax = 40
  integer, parameter :: lwork = m + n + 9 * kmax + 5 * kmax * kmax + 8 &
      + 16 * m
  integer, parameter :: liwork = 8 * kmax
  integer :: rep, i, kk, nmat_save
  integer :: iwork(liwork), iparm(1), ioption(2)
  double precision :: u(m, kmax + 1), sigma(k), bnd(k), v(n, kmax)
  double precision :: work(lwork), doption(3), dparm(n), tol
  double precision :: err
  common /ppcnt/ nmat_save
  external paprod, dlansvd
  ! A clear gap so four singular values converge inside kmax.
  dparm(1) = 100.0d0
  dparm(2) = 30.0d0
  dparm(3) = 8.0d0
  dparm(4) = 2.0d0
  do i = 5, n
    dparm(i) = 0.05d0
  end do
  tol = 1.0d-10
  doption(1) = 1.0d-8
  doption(2) = 1.0d-12
  doption(3) = 0.0d0
  ioption(1) = 1
  ioption(2) = 0
  iparm(1) = 0
  info = 0
  nmat = 0
  sigma_err = 0.0d0
  do rep = 1, nrep
    u = 0.0d0
    v = 0.0d0
    do i = 1, m
      u(i, 1) = 1.0d0
    end do
    nmat_save = 0
    kk = k
    call dlansvd('N', 'N', m, n, kk, kmax, paprod, u, m, sigma, bnd, &
        v, n, tol, work, lwork, iwork, liwork, doption, ioption, info, &
        dparm, iparm)
    nmat = nmat + nmat_save
    if (info /= 0) exit
    do i = 1, k
      err = abs(sigma(i) - dparm(i))
      if (err > sigma_err) sigma_err = err
    end do
  end do
end subroutine bench_propack
