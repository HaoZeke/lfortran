subroutine bench_id(nrep, krank_out, ndecomp, recon_err)
  implicit none
  integer, intent(in) :: nrep
  integer, intent(out) :: krank_out, ndecomp
  double precision, intent(out) :: recon_err
  integer, parameter :: m = 192
  integer, parameter :: n = 96
  integer, parameter :: krank = 8
  integer :: rep, i, j, p, k, ii, jj
  integer :: list(n)
  double precision :: a(m, n), acopy(m, n), col(m, krank)
  double precision :: proj(krank, n - krank), approx(m, n)
  double precision :: rnorms(n), diff
  external iddr_id, idd_reconid
  do j = 1, n
    do i = 1, m
      a(i, j) = 0.0d0
      do p = 1, krank
        a(i, j) = a(i, j) + sin(dble(p * i)) * cos(dble(p * j))
      end do
    end do
  end do
  recon_err = 0.0d0
  krank_out = 0
  do rep = 1, nrep
    acopy = a
    call iddr_id(m, n, acopy, krank, list, rnorms)
    do k = 1, krank
      do i = 1, m
        col(i, k) = a(i, list(k))
      end do
    end do
    ! proj is packed into the first krank*(n-krank) elements of acopy.
    p = 0
    do j = 1, n - krank
      do i = 1, krank
        p = p + 1
        ii = mod(p - 1, m) + 1
        jj = (p - 1) / m + 1
        proj(i, j) = acopy(ii, jj)
      end do
    end do
    call idd_reconid(m, krank, col, n, list, proj, approx)
    do j = 1, n
      do i = 1, m
        diff = abs(approx(i, j) - a(i, j))
        if (diff > recon_err) recon_err = diff
      end do
    end do
  end do
  krank_out = krank
  ndecomp = nrep
end subroutine bench_id
