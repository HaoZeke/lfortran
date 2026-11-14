module transpose_real10_01_m
    implicit none
    real(10) :: am(2, 2) = transpose(reshape([real(10) :: 1, 2, 3, 4], [2, 2]))
contains
    subroutine check_saved
        real(10) :: a(3, 3) = transpose(reshape([real(10) :: &
            1, 2, 3, 4, 5, 6, 7, 8, 9], [3, 3]))
        real(16) :: b(2, 2) = transpose(reshape([real(16) :: 1, 2, 3, 4], [2, 2]))
        if (a(1, 1) /= 1.0_10) error stop 1
        if (a(2, 1) /= 4.0_10) error stop 2
        if (a(1, 2) /= 2.0_10) error stop 3
        if (a(3, 3) /= 9.0_10) error stop 4
        if (b(1, 1) /= 1.0_16) error stop 5
        if (b(2, 1) /= 3.0_16) error stop 6
        if (b(1, 2) /= 2.0_16) error stop 7
    end subroutine check_saved
end module transpose_real10_01_m

program transpose_real10_01
    use transpose_real10_01_m
    implicit none
    if (am(1, 1) /= 1.0_10) error stop 8
    if (am(2, 1) /= 3.0_10) error stop 9
    if (am(1, 2) /= 2.0_10) error stop 10
    call check_saved
end program transpose_real10_01
