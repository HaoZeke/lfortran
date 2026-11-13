! The gradient is an element recurrence of x(i-1), x(i), x(i+1).
! Under --fast it must stay equal to the scalar formula, including when
! the loop is widened.
program rosen_grad_01
implicit none
integer, parameter :: n = 17
double precision :: x(n), g(n)
integer :: i
do i = 1, n
    x(i) = 0.1d0 * i - 0.7d0
end do
call grad(n, x, g)
if (abs(g(1) + 209.6d0) > 1.0d-8) error stop
if (abs(g(2) + 305.0d0) > 1.0d-8) error stop
if (abs(g(9) - 15.6d0) > 1.0d-8) error stop
if (abs(g(17) - 38.0d0) > 1.0d-8) error stop
contains
    subroutine grad(n, x, g)
        integer :: n
        double precision :: x(n), g(n)
        integer :: i
        g(1) = -2.0d0 * (1.0d0 - x(1)) - 400.0d0 * x(1) * (x(2) - x(1)**2)
        do i = 2, n - 1
            g(i) = -2.0d0 * (1.0d0 - x(i)) &
                - 400.0d0 * x(i) * (x(i + 1) - x(i)**2) &
                + 200.0d0 * (x(i) - x(i - 1)**2)
        end do
        g(n) = 200.0d0 * (x(n) - x(n - 1)**2)
    end subroutine
end program
