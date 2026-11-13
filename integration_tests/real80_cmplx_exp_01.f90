subroutine real80_cmplx_exp_01_run(x, y)
    ! The argument is not a constant, so exp is not folded.
    real(10), intent(in) :: x, y
    complex(10) :: z
    z = exp(cmplx(x, y, kind=10))
    if (abs(x) < 1.0e-8_10 .and. abs(y) < 1.0e-8_10) then
        if (abs(real(z) - 1.0_10) > 1.0e-8_10) error stop 1
        if (abs(aimag(z)) > 1.0e-8_10) error stop 2
    end if
    z = exp(cmplx(0.0_10, x, kind=10))
    if (abs(x - 1.0_10) < 1.0e-8_10) then
        if (abs(aimag(z) - sin(1.0_10)) > 1.0e-6_10) error stop 3
        if (abs(real(z) - cos(1.0_10)) > 1.0e-6_10) error stop 4
    end if
end subroutine real80_cmplx_exp_01_run

program real80_cmplx_exp_01
    real(10) :: x, y
    x = 0.0_10
    y = 0.0_10
    call real80_cmplx_exp_01_run(x, y)
    x = 1.0_10
    call real80_cmplx_exp_01_run(x, y)
end program real80_cmplx_exp_01
