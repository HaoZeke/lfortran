! f90wrap copies a class(T) pointer through integer(c_int) bits and back.
! The bits are already a pointer to a {vptr, data*} box.
module class_pointer_roundtrip_01_m
    implicit none

    type, abstract :: base
    contains
        procedure(get_value_i), deferred :: get_value
    end type base

    abstract interface
        subroutine get_value_i(self, value)
            import base
            class(base), intent(in) :: self
            real, intent(out) :: value
        end subroutine get_value_i
    end interface

    type, extends(base) :: impl
    contains
        procedure :: get_value => get_value_impl
    end type impl

    type :: wrapper
        class(base), allocatable :: obj
    end type wrapper

    type :: handle
        class(wrapper), pointer :: p => null()
    end type handle

contains

    subroutine get_value_impl(self, value)
        class(impl), intent(in) :: self
        real, intent(out) :: value
        value = 1.0
    end subroutine get_value_impl

end module class_pointer_roundtrip_01_m

program class_pointer_roundtrip_01
    use class_pointer_roundtrip_01_m
    use, intrinsic :: iso_c_binding, only: c_int
    implicit none

    type(handle) :: src, dst
    class(base), allocatable :: tmp
    integer(c_int) :: bits(2)
    real :: value

    allocate(src%p)
    allocate(impl :: tmp)
    call move_alloc(tmp, src%p%obj)
    bits = transfer(src, bits)
    dst = transfer(bits, dst)
    call dst%p%obj%get_value(value)
    if (abs(value - 1.0) > 1.0e-6) error stop 1
    print *, "ok"
end program class_pointer_roundtrip_01
