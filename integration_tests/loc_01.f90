program loc_01
    integer :: a(3)
    integer(8) :: d, e
    a(1) = 7
    d = loc(a)
    e = loc(a(1))
    if (d == 0) error stop "loc returned 0"
    if (d /= e) error stop "loc(array) differs from loc(element)"
    print *, a(1)
end program
