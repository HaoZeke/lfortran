program real80_read_array_01
    ! List-directed input of a real(10) array.
    implicit none
    real(10) :: a(2)
    integer :: u
    open(newunit=u, status='scratch')
    write(u, '(A)') '1.5 2.5'
    rewind(u)
    read(u, *) a
    close(u)
    if (abs(a(1) - 1.5_10) > 1.0e-8_10) error stop 1
    if (abs(a(2) - 2.5_10) > 1.0e-8_10) error stop 2
end program real80_read_array_01
