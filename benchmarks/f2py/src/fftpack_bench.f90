subroutine bench_rfft(nrep, err_pow2, err_gen)
  implicit none
  ! FFTPACK 4 real rfftf/rfftb, the copy SciPy 1.3.3 shipped.
  ! SciPy 1.14.1 no longer carries these sources. rfftb(rfftf(x)) = n*x.
  integer, intent(in) :: nrep
  real, intent(out) :: err_pow2, err_gen
  integer, parameter :: n_pow2 = 65536
  integer, parameter :: n_gen = 60000
  integer, parameter :: nmax = 65536
  real :: orig(nmax), work(nmax)
  real :: wsave_pow2(2 * n_pow2 + 15), wsave_gen(2 * n_gen + 15)
  interface
    subroutine rffti(n, wsave)
      integer :: n
      real :: wsave(*)
    end subroutine rffti
    subroutine fill_signal(n, x)
      integer :: n
      real :: x(*)
    end subroutine fill_signal
    real function round_trip(nrep, n, orig, work, wsave)
      integer :: nrep, n
      real :: orig(*), work(*), wsave(*)
    end function round_trip
  end interface
  call rffti(n_pow2, wsave_pow2)
  call rffti(n_gen, wsave_gen)
  call fill_signal(n_pow2, orig)
  err_pow2 = round_trip(nrep, n_pow2, orig, work, wsave_pow2)
  call fill_signal(n_gen, orig)
  err_gen = round_trip(nrep, n_gen, orig, work, wsave_gen)
end subroutine bench_rfft

subroutine fill_signal(n, x)
  implicit none
  integer :: n, i
  real :: x(n)
  real, parameter :: pi = 3.14159265
  do i = 1, n
    x(i) = sin(2.0 * pi * real(i) / real(n)) &
        + 0.5 * cos(4.0 * pi * real(i) / real(n))
  end do
end subroutine fill_signal

real function round_trip(nrep, n, orig, work, wsave)
  implicit none
  integer :: nrep, n, rep, i
  real :: orig(n), work(n), wsave(*)
  real :: err, e, scale
  external rfftf, rfftb
  do rep = 1, nrep
    do i = 1, n
      work(i) = orig(i)
    end do
    call rfftf(n, work, wsave)
    call rfftb(n, work, wsave)
  end do
  err = 0.0
  scale = real(n)
  do i = 1, n
    e = abs(work(i) / scale - orig(i))
    if (e > err) err = e
  end do
  round_trip = err
end function round_trip
