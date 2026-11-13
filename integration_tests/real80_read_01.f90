program real80_read_01
    ! List-directed internal read of real(10).
    implicit none
    character(len=32) :: s
    real(10) :: x
    s = "1.5"
    read(s, *) x
    if (abs(x - 1.5_10) > 1.0e-10_10) error stop 1
end program real80_read_01
