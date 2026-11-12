! allocated() on an unallocated character array must not dereference
! its null data pointer. This module is compiled separately so the
! zero-initialized descriptor is not visible to the caller.
module allocatable_character_array_01_m
    implicit none
    character(len=10), allocatable :: names(:)
contains
    logical function is_alloc()
        is_alloc = allocated(names)
    end function

    subroutine setup(n)
        integer, intent(in) :: n
        if (allocated(names)) deallocate(names)
        allocate(names(n))
        names = "test"
    end subroutine
end module
