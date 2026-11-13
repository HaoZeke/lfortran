subroutine bench_reduce(n, a, nrep, s)
  implicit none
  integer, intent(in) :: n, nrep
  double precision, intent(in) :: a(n)
  double precision, intent(out) :: s
  integer :: i, r
  s = 0.0d0
  do r = 1, nrep
    do i = 1, n
      s = s + a(i)
    end do
  end do
end subroutine bench_reduce
