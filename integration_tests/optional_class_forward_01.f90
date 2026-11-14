module optional_class_forward_01_mod
    type t
        integer :: state = 0
        character(len=8) :: message = 'ok'
    contains
        procedure :: handle
    end type
    interface assignment(=)
        module procedure assign
    end interface
contains
    elemental subroutine assign(to, from)
        class(t), intent(inout) :: to
        class(t), intent(in) :: from
        to%state = from%state
        to%message = from%message
    end subroutine
    pure subroutine handle(self, err)
        class(t), intent(in) :: self
        class(t), optional, intent(inout) :: err
        if (present(err)) err = self
    end subroutine
    subroutine symbol(err)
        type(t), intent(out), optional :: err
        type(t) :: err0
        call err0%handle(err)
    end subroutine
end module

program optional_class_forward_01
    use optional_class_forward_01_mod
    type(t) :: err
    call symbol()
    call symbol(err)
    if (err%state /= 0) error stop 1
    if (err%message /= 'ok') error stop 2
end program
