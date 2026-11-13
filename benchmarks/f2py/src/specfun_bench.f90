! Bessel and gamma sweep of the Fortran specfun SciPy carried through 1.8.0.
! SciPy 1.14.1 has rewritten this package in C.
subroutine bench_specfun(nrep, ncall, j0_err, gam_err, zero_err)
  implicit none
  integer, intent(in) :: nrep
  integer, intent(out) :: ncall
  double precision, intent(out) :: j0_err, gam_err, zero_err
  integer :: rep, k, nm, n
  double precision :: x, ga, j0_1
  double precision :: bj(0:16), dj(0:16), by(0:16), dy(0:16)
  double precision :: rj0(4), rj1(4), ry0(4), ry1(4)
  external jyna, gamma2, jyzo
  ncall = 0
  j0_1 = 0.0d0
  ga = 0.0d0
  rj0(1) = 0.0d0
  do rep = 1, nrep
    do k = 1, 16
      x = 0.25d0 * k
      call jyna(8, x, nm, bj, dj, by, dy)
      ncall = ncall + 1
      if (k == 4) j0_1 = bj(0)
    end do
    call gamma2(5.0d0, ga)
    ncall = ncall + 1
    call gamma2(0.5d0, ga)
    ncall = ncall + 1
    n = 0
    call jyzo(n, 4, rj0, rj1, ry0, ry1)
    ncall = ncall + 1
  end do
  j0_err = abs(j0_1 - 0.7651976865579666d0)
  gam_err = abs(ga - 1.772453850905516d0)
  zero_err = abs(rj0(1) - 2.404825557695773d0)
end subroutine bench_specfun
