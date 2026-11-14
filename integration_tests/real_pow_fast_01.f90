program real_pow_fast_01
    real :: a, y, e(1), r(1)
    real(8) :: b, z
    a = 2
    b = 2
    e = a
    ! The exponent is a value, so this is not the constant fold of 10**2.
    y = 10.0 ** a
    z = 10.0d0 ** b
    r = 10.0 ** e
    if (y /= 10.0 ** 2.0) error stop 1
    if (z /= 10.0d0 ** 2.0d0) error stop 2
    if (r(1) /= 10.0 ** 2.0) error stop 3
end program
