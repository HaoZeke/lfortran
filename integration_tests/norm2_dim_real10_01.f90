program norm2_dim_real10_01
    implicit none
    real(10) :: a(2, 2), r(2)
    real(16) :: b(2, 2), s(2)
    a(1, 1) = 3.0_10
    a(2, 1) = 4.0_10
    a(1, 2) = 0.0_10
    a(2, 2) = 0.0_10
    r = norm2(a, 1)
    if (abs(r(1) - 5.0_10) > 1.0e-6_10) error stop 1
    if (abs(r(2)) > 1.0e-6_10) error stop 2
    b(1, 1) = 3.0_16
    b(2, 1) = 4.0_16
    b(1, 2) = 0.0_16
    b(2, 2) = 0.0_16
    s = norm2(b, 1)
    if (abs(s(1) - 5.0_16) > 1.0e-6_16) error stop 3
    if (abs(s(2)) > 1.0e-6_16) error stop 4
end program norm2_dim_real10_01
