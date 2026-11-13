module reshape_cmplx10_01_m
    implicit none
    real(10), parameter :: src(4) = [-10, 2, 3, 4]
    complex(10), parameter :: csrc(4) = src
    complex(10) :: a(2, 2) = reshape(csrc, [2, 2])
    complex(10) :: b(2, 3) = reshape(csrc, [2, 3], &
        [complex(10) :: (9.0_10, -9.0_10)])
end module reshape_cmplx10_01_m

program reshape_cmplx10_01
    use reshape_cmplx10_01_m
    implicit none
    if (a(1, 1) /= (-10.0_10, 0.0_10)) error stop 1
    if (a(2, 1) /= (2.0_10, 0.0_10)) error stop 2
    if (a(1, 2) /= (3.0_10, 0.0_10)) error stop 3
    if (a(2, 2) /= (4.0_10, 0.0_10)) error stop 4
    if (b(2, 2) /= (4.0_10, 0.0_10)) error stop 5
    if (b(1, 3) /= (9.0_10, -9.0_10)) error stop 6
    if (b(2, 3) /= (9.0_10, -9.0_10)) error stop 7
end program reshape_cmplx10_01
