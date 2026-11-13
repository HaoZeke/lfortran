program loc_01
    integer :: a(3)
    integer(8) :: d
    a(1) = 7
    d = loc(a)
    if (d == 0) error stop "loc returned 0"
    print *, a(1)
end program
