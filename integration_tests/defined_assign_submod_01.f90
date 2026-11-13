module defined_assign_submod_01_errors
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
end module defined_assign_submod_01_errors

module defined_assign_submod_01_parent
    use defined_assign_submod_01_errors, only: state_type
    interface
        module subroutine touch()
        end subroutine touch
    end interface
contains
    subroutine set_state(err)
        type(state_type), intent(out) :: err
        type(state_type) :: err0
        err0%state = 4
        err = err0
    end subroutine set_state
end module defined_assign_submod_01_parent

submodule(defined_assign_submod_01_parent) defined_assign_submod_01_child
contains
    module subroutine touch()
        type(state_type) :: s
        call set_state(s)
        if (s%state /= 4) error stop 1
    end subroutine touch
end submodule defined_assign_submod_01_child

program defined_assign_submod_01
    use defined_assign_submod_01_parent
    call touch()
end program defined_assign_submod_01
