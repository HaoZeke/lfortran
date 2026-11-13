module array_ctor_real16_01_m
    implicit none
    real(10) :: x(2) = [1.0_10, -2.0_10]
    real(16) :: r(2) = [1.0_16, -2.0_16]
    complex(10) :: z(2) = [(3.0_10, -4.0_10), (5.0_10, 6.0_10)]
    complex(16) :: c(2) = [(3.0_16, -4.0_16), (5.0_16, 6.0_16)]
end module array_ctor_real16_01_m

program array_ctor_real16_01
    use array_ctor_real16_01_m
    implicit none
    if (x(1) /= 1.0_10) error stop 1
    if (x(2) /= -2.0_10) error stop 2
    if (r(1) /= 1.0_16) error stop 3
    if (r(2) /= -2.0_16) error stop 4
    if (z(1) /= (3.0_10, -4.0_10)) error stop 5
    if (z(2) /= (5.0_10, 6.0_10)) error stop 6
    if (c(1) /= (3.0_16, -4.0_16)) error stop 7
    if (c(2) /= (5.0_16, 6.0_16)) error stop 8
end program array_ctor_real16_01
