program cmplx_array_to_xdp_01
    integer, parameter :: xdp = selected_real_kind(18)
    complex(xdp) :: x(3)
    x = cmplx([4, 5, 6], [1, 2, 3], xdp)
    if (.not. all(x == cmplx([4, 5, 6], [1, 2, 3]))) error stop 1
    if (any(x - cmplx([4, 5, 6], [1, 2, 3]) /= (0, 0))) error stop 2
end program
