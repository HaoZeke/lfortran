module reshape_cmplx16_01_m
    implicit none
    complex(16), parameter :: src(4) = [ &
        (1.0_16, -1.0_16), (2.0_16, -2.0_16), &
        (3.0_16, -3.0_16), (4.0_16, -4.0_16)]
    complex(16) :: a(2, 2) = reshape(src, [2, 2])
    complex(16) :: b(2, 3) = reshape(src, [2, 3], &
        [complex(16) :: (9.0_16, -9.0_16)])
end module reshape_cmplx16_01_m

program reshape_cmplx16_01
    use reshape_cmplx16_01_m
    implicit none
    if (a(1, 1) /= (1.0_16, -1.0_16)) error stop 1
    if (a(2, 1) /= (2.0_16, -2.0_16)) error stop 2
    if (a(1, 2) /= (3.0_16, -3.0_16)) error stop 3
    if (a(2, 2) /= (4.0_16, -4.0_16)) error stop 4
    if (b(2, 2) /= (4.0_16, -4.0_16)) error stop 5
    if (b(1, 3) /= (9.0_16, -9.0_16)) error stop 6
    if (b(2, 3) /= (9.0_16, -9.0_16)) error stop 7
end program reshape_cmplx16_01
