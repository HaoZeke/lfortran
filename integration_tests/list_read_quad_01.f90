program list_read_quad_01
    integer, parameter :: qp = selected_real_kind(33)
    character(len=64) :: text
    real(qp) :: value
    text = "123-9"
    read(text, *) value
    if (abs(value - 1.23e-7_qp) > 1.0e-20_qp) error stop 1
    text = "1234567890123456789012345678901234567890-9"
    read(text, *) value
    if (value <= 0.0_qp) error stop 2
end program
