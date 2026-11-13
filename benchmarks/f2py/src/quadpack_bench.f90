double precision function quad_f(x)
  implicit none
  double precision :: x
  quad_f = 1.0d0 / sqrt(x)
end function quad_f

subroutine bench_dqags(nrep, result, abserr, neval, ier)
  implicit none
  integer, intent(in) :: nrep
  double precision, intent(out) :: result, abserr
  integer, intent(out) :: neval, ier
  integer, parameter :: limit = 500
  integer :: lenw, last, i, ne
  double precision :: a, b, epsabs, epsrel, acc
  double precision :: work(4 * limit)
  integer :: iwork(limit)
  double precision, external :: quad_f
  interface
    subroutine dqags(f, a, b, epsabs, epsrel, result, abserr, neval, ier, &
        limit, lenw, last, iwork, work)
      double precision, external :: f
      double precision :: a, b, epsabs, epsrel, result, abserr
      integer :: neval, ier, limit, lenw, last
      integer :: iwork(*)
      double precision :: work(*)
    end subroutine dqags
  end interface
  a = 0.0d0
  b = 1.0d0
  epsabs = 1.0d-12
  epsrel = 1.0d-10
  lenw = 4 * limit
  acc = 0.0d0
  result = 0.0d0
  abserr = 0.0d0
  neval = 0
  ier = 0
  do i = 1, nrep
    call dqags(quad_f, a, b, epsabs, epsrel, result, abserr, ne, ier, &
        limit, lenw, last, iwork, work)
    acc = acc + result
    neval = neval + ne
    if (ier /= 0) exit
  end do
  result = acc
end subroutine bench_dqags
