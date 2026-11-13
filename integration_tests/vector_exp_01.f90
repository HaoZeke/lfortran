program vector_exp_01
implicit none
integer, parameter :: n = 64
double precision :: x(n), s, a
integer :: i
a = -1.0d-2
s = 0.0d0
do i = 1, n
    x(i) = exp(a * dble(i))
    s = s + x(i)
end do
if (abs(x(1) - 9.900498337491681d-1) > 1.0d-12) error stop
if (abs(x(10) - 9.048374180359595d-1) > 1.0d-12) error stop
if (abs(x(64) - 5.272924240430486d-1) > 1.0d-12) error stop
if (abs(s - 47.0347977300401d0) > 1.0d-8) error stop
if (abs(exp(1.0d0) - 2.718281828459045d0) > 1.0d-12) error stop
end program
