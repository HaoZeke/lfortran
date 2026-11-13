program real80_log_gamma_01
    implicit none
    real(kind=10) :: x
    x = log_gamma(1.0_10)
    if (abs(x) > 1.0e-6_10) error stop 1
    x = log_gamma(2.0_10)
    if (abs(x) > 1.0e-6_10) error stop 2
end program
