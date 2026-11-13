subroutine bench_triple(n, a, b, c)
  implicit none
  integer, intent(in) :: n
  double precision, intent(in) :: a(n, n), b(n, n)
  double precision, intent(out) :: c(n, n)
  integer :: i, j, k
  double precision :: acc
  do j = 1, n
    do i = 1, n
      acc = 0.0d0
      do k = 1, n
        acc = acc + a(i, k) * b(k, j)
      end do
      c(i, j) = acc
    end do
  end do
end subroutine bench_triple
