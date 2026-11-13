program real80_complex_real_01
    ! real() of a complex(10) value is the real part, at the same kind.
    implicit none
    complex(10) :: z
    real(10) :: r, i
    z = (1.5_10, -2.5_10)
    r = real(z)
    i = aimag(z)
    if (r /= 1.5_10) error stop 1
    if (i /= -2.5_10) error stop 2
end program
