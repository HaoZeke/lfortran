program real80_acos_01
    ! sqrt and acos of real(10) fold, including inside a named constant.
    implicit none
    real(10), parameter :: sqrt_2_pi = sqrt(2.0_10*acos(-1.0_10))
    real(10) :: y
    y = -1.0_10
    if (abs(sqrt_2_pi - sqrt(2.0_10*acos(y))) > 1.0e-10_10) error stop 1
end program real80_acos_01
