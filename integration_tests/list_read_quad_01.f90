program list_read_quad_01
    integer, parameter :: qp = selected_real_kind(33)
    character(len=128) :: text
    real(qp) :: value
    text = "123-9"
    read(text, *) value
    if (abs(value - 1.23e-7_qp) > 1.0e-20_qp) error stop 1
    text = "1234567890123456789012345678901234567890-9"
    read(text, *) value
    if (value <= 0.0_qp) error stop 2
    text = "0.140129846432481707092372958328991613128026194187651577" // &
        "175706828388979108268586060148663818836212158203125E-44"
    read(text, *) value
    if (value < 1.0e-46_qp .or. value > 1.0e-44_qp) error stop 3
end program
