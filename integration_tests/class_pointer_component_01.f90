! A pointer component is not deallocated when its derived type goes
! out of scope. f90wrap keeps that pointer and uses it after the
! local derived type has been finalized.
module class_pointer_component_01_m
    implicit none
    type :: payload
        integer :: n = 0
    end type
    type :: box
        class(payload), allocatable :: obj
    end type
    type :: handle
        class(box), pointer :: p => null()
    end type
contains
    subroutine stash(out)
        class(box), pointer, intent(out) :: out
        type(handle) :: local
        allocate(local%p)
        allocate(payload :: local%p%obj)
        local%p%obj%n = 3
        out => local%p
    end subroutine
end module

program class_pointer_component_01
    use class_pointer_component_01_m
    implicit none
    class(box), pointer :: got
    call stash(got)
    if (.not. associated(got)) error stop 1
    if (got%obj%n /= 3) error stop 2
    deallocate(got%obj)
    deallocate(got)
    print *, "ok"
end program
