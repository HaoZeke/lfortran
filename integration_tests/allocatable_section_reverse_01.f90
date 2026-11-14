program allocatable_section_reverse_01
    real, allocatable :: v(:, :)
    integer :: p, i
    p = 4
    allocate(v(p, p))
    v = reshape([(real(i), i = 1, p*p)], [p, p])
    v = v(:, p:1:-1)
    if (v(1, 1) /= 13.0 .or. v(1, p) /= 1.0) error stop 1
    if (v(4, 1) /= 16.0 .or. v(4, p) /= 4.0) error stop 2
end program
