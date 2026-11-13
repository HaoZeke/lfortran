! Inverse-cdf sweep of the Fortran cdflib SciPy carried through 1.5.4.
! SciPy 1.14.1 has rewritten this package in C.
subroutine bench_cdflib(nrep, ncall, nor_err, gam_err, nbad)
  implicit none
  integer, intent(in) :: nrep
  integer, intent(out) :: ncall, nbad
  double precision, intent(out) :: nor_err, gam_err
  integer :: rep, i, which, status
  double precision :: p, q, x, mean, sd, bound
  double precision :: shape, scale, xhalf, xgam
  external cdfnor, cdfgam
  ncall = 0
  nbad = 0
  xhalf = 0.0d0
  xgam = 0.0d0
  mean = 0.0d0
  sd = 1.0d0
  shape = 1.0d0
  scale = 1.0d0
  do rep = 1, nrep
    do i = 1, 40
      p = dble(i) / 41.0d0
      q = 1.0d0 - p
      which = 2
      x = 0.0d0
      call cdfnor(which, p, q, x, mean, sd, status, bound)
      ncall = ncall + 1
      if (status /= 0) nbad = nbad + 1
      if (i == 21) xhalf = x
      x = 0.0d0
      call cdfgam(which, p, q, x, shape, scale, status, bound)
      ncall = ncall + 1
      if (status /= 0) nbad = nbad + 1
      if (i == 21) xgam = x
    end do
  end do
  ! Standard-normal median is 0. i = 21 is p = 21/41, not 1/2, so the
  ! median is requested on its own below. Exponential median is ln(2).
  p = 0.5d0
  q = 0.5d0
  which = 2
  x = 0.0d0
  call cdfnor(which, p, q, x, mean, sd, status, bound)
  ncall = ncall + 1
  if (status /= 0) nbad = nbad + 1
  nor_err = abs(x)
  ! p = 21/41 is not 1/2. Its normal quantile is about 0.0306. A sweep
  ! that never reached i = 21 leaves xhalf at 0.
  nor_err = max(nor_err, abs(xhalf - 0.030641d0))
  ! The 21/41 quantile is only a sweep witness. A few ulps is the
  ! same inversion.
  x = 0.0d0
  call cdfgam(which, p, q, x, shape, scale, status, bound)
  ncall = ncall + 1
  if (status /= 0) nbad = nbad + 1
  gam_err = abs(x - log(2.0d0))
end subroutine bench_cdflib
