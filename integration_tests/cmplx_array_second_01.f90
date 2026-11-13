program cmplx_array_second_01
    implicit none
    real(16), parameter :: pi = 4.0_16 * atan(1.0_16)
    real(16), allocatable :: theta(:)
    complex(16), allocatable :: z(:)
    theta = [-180.0_16, 0.0_16, 180.0_16]
    z = cmplx(0.0_16, theta / 180.0_16 * pi, kind=16)
    if (size(z) /= 3) error stop 1
    if (abs(real(z(2))) > 1.0e-8_16) error stop 2
    if (abs(aimag(z(2))) > 1.0e-8_16) error stop 3
    if (abs(aimag(z(3)) - pi) > 1.0e-6_16) error stop 4
end program cmplx_array_second_01
