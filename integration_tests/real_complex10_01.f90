program real_complex10_01
    ! real() of a complex(10) named constant is the real part.
    implicit none
    complex(10), parameter :: z = (1.5_10, -2.5_10)
    real(10), parameter :: r = real(z, kind=10)
    if (r /= 1.5_10) error stop 1
end program real_complex10_01
