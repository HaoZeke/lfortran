program loc_allocatable_01
    real(8), allocatable :: a(:)
    integer(8) :: d, e
    allocate(a(2))
    a(1) = 1.5d0
    a(2) = 2.5d0
    d = loc(a)
    e = loc(a(1))
    if (d == 0) error stop "loc returned 0"
    if (d /= e) error stop "loc(allocatable) is not its first element"
    print *, a(1)
end program loc_allocatable_01
