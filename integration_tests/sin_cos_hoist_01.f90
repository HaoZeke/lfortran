! sin(p*i)*cos(p*j) over a grid. gfortran -O3 hoists the cosines out of
! the inner loop. The stored bits are that strict evaluation: the sum over
! p stays in order, and each sine and cosine is the libm value.
program sin_cos_hoist_01
implicit none
integer, parameter :: m = 24
integer, parameter :: n = 12
integer, parameter :: k = 4
double precision :: a(m, n), s
integer :: i, j, p
s = 0.0d0
do j = 1, n
    do i = 1, m
        a(i, j) = 0.0d0
        do p = 1, k
            a(i, j) = a(i, j) + sin(dble(p * i)) * cos(dble(p * j))
        end do
        s = s + a(i, j)
    end do
end do
if (transfer(a(1, 1), 0_8) /= 4601439767945941939_8) error stop
if (transfer(a(m, n), 0_8) /= -4612802137925611566_8) error stop
if (transfer(s, 0_8) /= -4622759120750598444_8) error stop
end program
