program real80_inquiry_01
    ! Numeric inquiries of real(10) are the 80-bit values, not double.
    implicit none
    real(10) :: x
    x = 1.0_10
    if (digits(x) /= 64) error stop 1
    if (minexponent(x) /= -16381) error stop 2
    if (maxexponent(x) /= 16384) error stop 3
end program real80_inquiry_01
