program size_dim_kind_01
    integer, allocatable :: y(:,:)
    integer(8) :: i, s
    allocate(y(2, 3))
    i = 1
    s = size(y, i)
    if (s /= 2) error stop "size dim 1"
    i = 2
    s = size(y, i)
    if (s /= 3) error stop "size dim 2"
    print *, "ok"
end program
