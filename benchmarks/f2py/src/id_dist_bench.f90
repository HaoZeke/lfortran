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

subroutine bench_id_extra(nrep, info, nsv, fft_err, svd_err)
  implicit none
  integer, intent(in) :: nrep
  integer, intent(out) :: info, nsv
  double precision, intent(out) :: fft_err, svd_err
  integer, parameter :: nfft = 32
  integer, parameter :: m = 16
  integer, parameter :: n = 8
  integer, parameter :: krank = 2
  integer, parameter :: lwork = (krank + 2) * n + 8 * n + 15 * krank * krank + 8 * krank + 64
  integer :: rep, i, j, ier
  double precision :: x(nfft), x0(nfft), wsave(2 * nfft + 15)
  double precision :: a(m, n), u(m, krank), v(n * krank), s(krank), r(lwork)
  double precision :: diff
  external dffti, dfftf, dfftb, iddr_svd
  do i = 1, nfft
    x0(i) = sin(dble(i) * 0.37d0)
  end do
  call dffti(nfft, wsave)
  do j = 1, n
    do i = 1, m
      if (i == j) then
        a(i, j) = dble(5 - j)
      else
        a(i, j) = 0.0d0
      end if
    end do
  end do
  fft_err = 0.0d0
  svd_err = 0.0d0
  info = 0
  do rep = 1, nrep
    x = x0
    call dfftf(nfft, x, wsave)
    call dfftb(nfft, x, wsave)
    do i = 1, nfft
      diff = abs(x(i) / dble(nfft) - x0(i))
      if (diff > fft_err) fft_err = diff
    end do
    call iddr_svd(m, n, a, krank, u, v, s, ier, r)
    if (ier /= 0) then
      info = ier
      exit
    end if
    diff = abs(s(1) - 4.0d0)
    if (diff > svd_err) svd_err = diff
    diff = abs(s(2) - 3.0d0)
    if (diff > svd_err) svd_err = diff
    do j = 1, n
      do i = 1, m
        if (i == j) then
          a(i, j) = dble(5 - j)
        else
          a(i, j) = 0.0d0
        end if
      end do
    end do
  end do
  nsv = nrep
end subroutine bench_id_extra
