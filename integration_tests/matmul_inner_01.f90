! ijk product. The contiguous index must be able to run innermost without
! changing the sum, including under --fast --no-fast-math.
program matmul_inner_01
implicit none
integer, parameter :: n = 8
double precision :: a(n, n), b(n, n), c(n, n), acc
integer :: i, j, k
do j = 1, n
    do i = 1, n
        a(i, j) = 0.5d0 * i + j
        b(i, j) = i - 0.25d0 * j
    end do
end do
do j = 1, n
    do i = 1, n
        acc = 0.0d0
        do k = 1, n
            acc = acc + a(i, k) * b(k, j)
        end do
        c(i, j) = acc
    end do
end do
if (abs(c(1, 1) - 212.0d0) > 1.0d-8) error stop
if (abs(c(2, 3) - 207.0d0) > 1.0d-8) error stop
if (abs(c(n, n) - 212.0d0) > 1.0d-8) error stop
end program
