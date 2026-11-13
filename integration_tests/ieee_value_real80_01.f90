program ieee_value_real80_01
    ! ieee_value of a real(10) argument returns a value of the requested class.
    use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, &
        ieee_positive_inf
    implicit none
    real(10) :: nan, inf
    nan = ieee_value(1.0_10, ieee_quiet_nan)
    if (nan == nan) error stop 1
    inf = ieee_value(1.0_10, ieee_positive_inf)
    if (.not. (inf > huge(1.0_10))) error stop 2
end program
