program real80_reshape_01
    ! A real(10) scalar times an integer array is a compile-time constant.
    implicit none
    real(10), parameter :: rsqrt2 = 1.0_10/sqrt(2.0_10)
    real(10), parameter :: u_sol(2, 2) = reshape(rsqrt2*[1, 1, 1, -1], [2, 2])
    if (abs(u_sol(1, 1) - rsqrt2) > 1.0e-10_10) error stop 1
    if (abs(u_sol(2, 2) + rsqrt2) > 1.0e-10_10) error stop 2
end program real80_reshape_01
