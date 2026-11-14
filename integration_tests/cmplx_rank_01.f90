module cmplx_rank_01_m
contains
    elemental function myarg(z) result(r)
        complex, intent(in) :: z
        real :: r
        r = atan2(aimag(z), real(z))
    end function myarg
end module cmplx_rank_01_m

program cmplx_rank_01
    use cmplx_rank_01_m
    implicit none
    real :: theta(3), a(3)
    complex :: one
    integer :: n(3)
    complex :: w(3)
    theta = [0.0, 45.0, 90.0]
    a = myarg(exp(cmplx(0.0, theta)))
    one = exp(cmplx(0.0, 45.0))
    if (abs(a(2) - atan2(aimag(one), real(one))) > 1.0e-5) error stop 1
    if (abs(a(1)) > 1.0e-5) error stop 2
    n = [4, 5, 6]
    w = cmplx(1, n)
    if (abs(aimag(w(2)) - 5.0) > 1.0e-5) error stop 3
end program cmplx_rank_01
