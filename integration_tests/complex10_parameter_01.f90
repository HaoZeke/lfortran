program complex10_parameter_01
    ! A complex(10) named constant is a compile-time value.
    implicit none
    integer, parameter :: xdp = selected_real_kind(18)
    complex(xdp), parameter :: zero_cxdp = (0._xdp, 0._xdp)
    complex(10), parameter :: w = (1.5_10, -2.5_10)
    if (zero_cxdp /= (0._xdp, 0._xdp)) error stop 1
    if (w /= (1.5_10, -2.5_10)) error stop 2
end program
