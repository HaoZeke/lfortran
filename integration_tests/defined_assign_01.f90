module defined_assign_01_state
    type :: state_type
        integer :: state = 0
    end type state_type
    interface assignment(=)
        module procedure state_assign_state
    end interface
contains
    elemental subroutine state_assign_state(to, from)
        class(state_type), intent(inout) :: to
        class(state_type), intent(in) :: from
        to%state = from%state
    end subroutine state_assign_state
end module defined_assign_01_state

module defined_assign_01_child
    use defined_assign_01_state, only: state_type
    type, extends(state_type) :: child
    end type child
contains
    subroutine copy(ierr, ierr_out)
        type(child), intent(in) :: ierr
        type(child), optional, intent(out) :: ierr_out
        if (present(ierr_out)) then
            ierr_out = ierr
        end if
    end subroutine copy
    subroutine copy_same(a, b)
        type(state_type), intent(in) :: a
        type(state_type), intent(out) :: b
        b = a
    end subroutine copy_same
end module defined_assign_01_child

program defined_assign_01
    use defined_assign_01_child
    implicit none
    type(child) :: a, b
    type(state_type) :: s, t
    a%state = 3
    call copy(a, b)
    if (b%state /= 3) error stop 1
    s%state = 4
    call copy_same(s, t)
    if (t%state /= 4) error stop 2
end program defined_assign_01
