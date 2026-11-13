program real80_implied_do_01
    ! An implied-do of real(10) powers is a compile-time array.
    implicit none
    integer :: e
    real(10), parameter :: a(3) = [(10.0_10**(3 - e), e = 1, 3)]
    if (a(1) /= 100.0_10) error stop 1
    if (a(2) /= 10.0_10) error stop 2
    if (a(3) /= 1.0_10) error stop 3
end program real80_implied_do_01
