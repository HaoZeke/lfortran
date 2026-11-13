program real80_read_cmplx_array_01
    ! List-directed input of a complex(10) array.
    implicit none
    complex(10) :: z(2)
    integer :: u
    open(newunit=u, status='scratch')
    write(u, '(A)') '(1.5,-2.5) (3.0,4.0)'
    rewind(u)
    read(u, *) z
    close(u)
    if (abs(real(z(1)) - 1.5_10) > 1.0e-8_10) error stop 1
    if (abs(aimag(z(1)) + 2.5_10) > 1.0e-8_10) error stop 2
    if (abs(real(z(2)) - 3.0_10) > 1.0e-8_10) error stop 3
    if (abs(aimag(z(2)) - 4.0_10) > 1.0e-8_10) error stop 4
end program real80_read_cmplx_array_01
