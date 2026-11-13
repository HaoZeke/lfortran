subroutine bench_setulb(n, f, nfg, info)
  implicit none
  integer, intent(in) :: n
  double precision, intent(out) :: f
  integer, intent(out) :: nfg, info
  integer, parameter :: m = 10
  integer, parameter :: maxls = 20
  integer :: iprint, i, nbd(n), iwa(3 * n), isave(44)
  double precision :: factr, pgtol, g(n), l(n), u(n), x(n)
  double precision :: wa(2 * m * n + 5 * n + 11 * m * m + 8 * m), dsave(29)
  logical :: lsave(4)
  character(len=60) :: task, csave
  interface
    subroutine setulb(n, m, x, l, u, nbd, f, g, factr, pgtol, wa, iwa, &
        task, iprint, csave, lsave, isave, dsave, maxls)
      integer :: n, m, iprint, maxls
      double precision :: f, factr, pgtol
      double precision :: x(*), l(*), u(*), g(*), wa(*), dsave(*)
      integer :: nbd(*), iwa(*), isave(*)
      logical :: lsave(*)
      character(len=60) :: task, csave
    end subroutine setulb
  end interface
  factr = 1.0d7
  pgtol = 1.0d-5
  iprint = -1
  do i = 1, n
    x(i) = -1.2d0
    l(i) = 0.0d0
    u(i) = 0.0d0
    nbd(i) = 0
  end do
  task = 'START'
  nfg = 0
  info = 1
  f = 0.0d0
  do i = 1, 20000
    call setulb(n, m, x, l, u, nbd, f, g, factr, pgtol, wa, iwa, &
        task, iprint, csave, lsave, isave, dsave, maxls)
    if (task(1:2) == 'FG') then
      call rosenbrock(n, x, f, g)
      nfg = nfg + 1
    else if (task(1:5) == 'NEW_X') then
      continue
    else if (task(1:4) == 'CONV') then
      info = 0
      exit
    else
      info = 2
      exit
    end if
  end do
end subroutine bench_setulb

subroutine rosenbrock(n, x, f, g)
  implicit none
  integer :: n
  double precision :: x(n), f, g(n)
  integer :: i
  f = 0.0d0
  do i = 1, n - 1
    f = f + (1.0d0 - x(i))**2 + 100.0d0 * (x(i + 1) - x(i)**2)**2
  end do
  g(1) = -2.0d0 * (1.0d0 - x(1)) - 400.0d0 * x(1) * (x(2) - x(1)**2)
  do i = 2, n - 1
    g(i) = -2.0d0 * (1.0d0 - x(i)) &
        - 400.0d0 * x(i) * (x(i + 1) - x(i)**2) &
        + 200.0d0 * (x(i) - x(i - 1)**2)
  end do
  g(n) = 200.0d0 * (x(n) - x(n - 1)**2)
end subroutine rosenbrock
