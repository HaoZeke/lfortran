program real_to_complex_xdp_01
    integer, parameter :: xdp = selected_real_kind(18)
    real(xdp), parameter :: coef = 0.01_xdp
    complex(xdp) :: c, det
    c = coef
    det = 1.0_xdp
    det = det*c
    det = det*c
    det = det*c
    det = det*c
    if (abs(det - coef**4) > epsilon(coef)*coef**4) error stop 1
end program
