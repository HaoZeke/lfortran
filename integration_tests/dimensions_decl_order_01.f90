! A dummy may be used in a dimension before its own declaration.
program dimensions_decl_order_01
    implicit none
    real :: a(2, 3)
    real :: b(2)
    a = 1.0
    a(1, 2) = 4.0
    call foo(a, 2, 3, b)
    if (abs(b(1) - 6.0) > 1e-6) error stop 1
    if (abs(b(2) - 3.0) > 1e-6) error stop 2
contains
subroutine foo(a, n, m, b)
    implicit none
    real, intent(in) :: a(n, m)
    integer, intent(in) :: n, m
    real, intent(out) :: b(size(a, 1))
    integer :: i
    do i = 1, size(b)
        b(i) = sum(a(i, :))
    end do
end subroutine
end program
