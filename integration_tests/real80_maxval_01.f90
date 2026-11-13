program real80_maxval_01
    ! maxval and minval of real(10), including an empty array.
    implicit none
    real(10) :: empty(0)
    real(10) :: b(2)
    b = [1.0_10, -4.0_10]
    if (maxval(b) /= 1.0_10) error stop 1
    if (minval(b) /= -4.0_10) error stop 2
    if (.not. (maxval(empty) < 0.0_10)) error stop 3
    if (.not. (minval(empty) > 0.0_10)) error stop 4
end program real80_maxval_01
