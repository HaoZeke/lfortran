program real80_cmplx_pow_01
    ! complex(10) raised to an integer and to a complex power.
    implicit none
    complex(10) :: z
    z = (2.0_10, 0.0_10) ** 3
    if (abs(real(z) - 8.0_10) > 1.0e-8_10) error stop 1
    if (abs(aimag(z)) > 1.0e-8_10) error stop 2
    z = (2.0_10, 0.0_10) ** (2.0_10, 0.0_10)
    if (abs(real(z) - 4.0_10) > 1.0e-6_10) error stop 3
end program real80_cmplx_pow_01
