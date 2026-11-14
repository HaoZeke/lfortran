module scalar_array_real10_01_m
    implicit none
    integer, parameter :: n = 3
    real(10), parameter :: a(n) = 1.0_10
    real(16), parameter :: b(2) = -2.0_16
    real(10) :: c(3) = 3.0_10
contains
    subroutine check_block
        integer, parameter :: m = 4
        block
            real(10), parameter :: x(m) = 4.0_10
            if (x(1) /= 4.0_10) error stop 5
            if (x(m) /= 4.0_10) error stop 6
        end block
    end subroutine check_block
end module scalar_array_real10_01_m

program scalar_array_real10_01
    use scalar_array_real10_01_m
    implicit none
    if (a(1) /= 1.0_10) error stop 1
    if (a(n) /= 1.0_10) error stop 2
    if (b(1) /= -2.0_16) error stop 3
    if (b(2) /= -2.0_16) error stop 4
    if (c(1) /= 3.0_10) error stop 7
    if (c(3) /= 3.0_10) error stop 8
    call check_block
end program scalar_array_real10_01
