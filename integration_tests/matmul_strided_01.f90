program matmul_strided_01
implicit none
integer, parameter :: n = 32
double precision :: a(n, n), b(n, n), c(n, n), s
integer :: i, j, k
do j = 1, n
    do i = 1, n
        a(i, j) = 0.5d0*dble(i) + dble(j)
        b(i, j) = dble(i) - 0.25d0*dble(j)
        c(i, j) = 0.0d0
    end do
end do
do j = 1, n
    do i = 1, n
        do k = 1, n
            c(i, j) = c(i, j) + a(i, k)*b(k, j)
        end do
    end do
end do
s = 0.0d0
do k = 1, n
    s = s + (0.5d0 + dble(k))*(dble(k) - 0.25d0)
end do
if (abs(c(1, 1) - s) > 1.0d-8) error stop
s = 0.0d0
do k = 1, n
    s = s + (0.5d0*dble(n) + dble(k))*(dble(k) - 0.25d0*dble(n))
end do
if (abs(c(n, n) - s) > 1.0d-6) error stop
end program
