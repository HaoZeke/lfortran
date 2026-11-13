program real80_cmplx_01
    ! A real(10) or an integer becomes the real part of a complex(10).
    implicit none
    complex(10) :: z
    real(10) :: x
    x = 1.5_10
    z = x
    if (abs(real(z) - 1.5_10) > 1.0e-10_10) error stop 1
    z = 2
    if (abs(real(z) - 2.0_10) > 1.0e-10_10) error stop 2
    if (abs(aimag(z)) > 1.0e-10_10) error stop 3
end program real80_cmplx_01
