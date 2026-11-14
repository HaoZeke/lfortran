program int_array_to_complex10_01
    integer, parameter :: kp = selected_real_kind(18)
    complex(kp), parameter :: e(2) = [1, 2]
    integer, parameter :: m2 = 2, n2 = 3, m1 = 1, n1 = 2
    complex(kp), parameter :: expected(m1*m2, n1*n2) = transpose(reshape( &
        [1, 2, 3, 2, 4, 6, 2, 4, 6, 4, 8, 12], [m2*n2, m1*n1]))
    integer :: k
    k = 1
    ! A runtime index must load the stored element. Folding the
    ! constructor as an integer array leaves this as a NaN.
    if (e(k) /= (1.0_kp, 0.0_kp)) error stop 1
    if (e(2) /= (2.0_kp, 0.0_kp)) error stop 2
    if (expected(k, k) /= (1.0_kp, 0.0_kp)) error stop 3
    if (expected(2, 6) /= (12.0_kp, 0.0_kp)) error stop 4
end program
