program ieee_is_nan_real80_01
    ! ieee_is_nan of a real(10) value.
    use, intrinsic :: ieee_arithmetic, only: ieee_is_nan, ieee_value, ieee_quiet_nan
    implicit none
    real(10) :: x
    x = 1.0_10
    if (ieee_is_nan(x)) error stop 1
    x = ieee_value(x, ieee_quiet_nan)
    if (.not. ieee_is_nan(x)) error stop 2
end program ieee_is_nan_real80_01
