program min_associate_bound_01
    type :: bounds
        integer :: n
    end type bounds
    type(bounds) :: a
    integer :: i, j, k
    a%n = 10
    i = 1
    k = 0
    associate (n => a%n)
        do j = i, min(i + 3, n)
            k = j
        end do
    end associate
    if (k /= 4) error stop 1
end program min_associate_bound_01
