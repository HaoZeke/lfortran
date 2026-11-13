program implied_shape_pack_01
    implicit none
    integer, parameter :: xtest(*) = [0, 1, 2, 4, 5, 7, 12, 20, 100, 500]
    real(10), parameter :: res(*) = [0.0_10, 1.0_10, 2.0_10, 3.0_10, 4.0_10, &
        5.0_10, 6.0_10, 7.0_10, 8.0_10, 9.0_10]
    real(10), parameter :: ans(*) = pack(res, xtest < huge(0_1))
    if (size(ans) /= 9) error stop 1
    if (abs(ans(1) - 0.0_10) > 1.0e-6_10) error stop 2
    if (abs(ans(9) - 8.0_10) > 1.0e-6_10) error stop 3
end program implied_shape_pack_01
