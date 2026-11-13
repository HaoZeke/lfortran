! f90wrap passes a type(T) pointer through integer(c_int) bits into a
! class(T) pointer, then calls a type-bound procedure on the target.
module class_pointer_dispatch_01_m
    implicit none
    type :: rectangle
        real :: length = 0
    contains
        procedure :: is_square => rectangle_is_square
    end type
    type, extends(rectangle) :: square
    contains
        procedure :: is_square => square_is_square
        procedure :: is_equal => square_is_equal
    end type
    type :: square_wrapper
        class(square), allocatable :: obj
    end type
    type :: square_handle
        type(square_wrapper), pointer :: p => null()
    end type
    type :: rectangle_wrapper
        class(rectangle), allocatable :: obj
    end type
    type :: rectangle_handle
        class(rectangle_wrapper), pointer :: p => null()
    end type
contains
    function rectangle_is_square(this) result(r)
        class(rectangle), intent(in) :: this
        integer :: r
        r = 0
    end function
    function square_is_square(this) result(r)
        class(square), intent(in) :: this
        integer :: r
        r = 1
    end function
    function square_is_equal(this, other) result(r)
        class(square), intent(in) :: this
        class(rectangle), intent(in) :: other
        integer :: r
        if (other%is_square() == 1 .and. this%length == other%length) then
            r = 1
        else
            r = 0
        end if
    end function
end module

program class_pointer_dispatch_01
    use class_pointer_dispatch_01_m
    use, intrinsic :: iso_c_binding, only: c_int
    implicit none
    type(square_handle) :: s1, s2
    type(rectangle_handle) :: as_rect
    integer(c_int) :: bits(2)
    allocate(s1%p)
    allocate(square :: s1%p%obj)
    s1%p%obj%length = 3
    allocate(s2%p)
    allocate(square :: s2%p%obj)
    s2%p%obj%length = 3
    bits = transfer(s2, bits)
    as_rect = transfer(bits, as_rect)
    if (s1%p%obj%is_equal(as_rect%p%obj) /= 1) error stop 1
    print *, "ok"
end program
