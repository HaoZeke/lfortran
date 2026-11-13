module realloc_unalloc_array_02_mod
    implicit none
contains
    pure function lin(start, end, n) result(res)
        real, intent(in) :: start, end
        integer, intent(in) :: n
        real :: res(max(n, 0))
        integer :: i
        real :: interval
        if (n <= 0) return
        if (n == 1) then
            res(1) = end
            return
        end if
        interval = (end - start) / real(n - 1)
        res(1) = start
        res(n) = end
        do i = 2, n - 1
            res(i) = real(i - 1) * interval + start
        end do
    end function

    pure function diag(v) result(res)
        real, intent(in) :: v(:)
        real :: res(size(v), size(v))
        integer :: i
        res = 0.0
        do i = 1, size(v)
            res(i, i) = v(i)
        end do
    end function
end module

program realloc_unalloc_array_02
    use realloc_unalloc_array_02_mod
    implicit none
    real, allocatable :: x(:)
    real, allocatable :: a(:, :)
    real :: v(3)

    x = lin(1.0, 10.0, 20)
    if (size(x) /= 20) error stop 1
    if (abs(x(1) - 1.0) > 1.0e-5) error stop 2
    if (abs(x(20) - 10.0) > 1.0e-4) error stop 3

    x = lin(1.0, 4.0, 4)
    if (size(x) /= 4) error stop 4
    if (abs(x(4) - 4.0) > 1.0e-5) error stop 5

    v = [1.0, 2.0, 3.0]
    a = diag(v)
    if (any(shape(a) /= [3, 3])) error stop 6
    if (a(2, 2) /= 2.0) error stop 7
    if (a(1, 2) /= 0.0) error stop 8
end program
