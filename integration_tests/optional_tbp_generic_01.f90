module optional_tbp_generic_01_mod
    type :: item
        integer :: n = 1
    contains
        generic :: put => put_string
        procedure :: put_string
    end type
contains
    subroutine put_string(self, text, code)
        class(item), intent(in) :: self
        character(len=:), allocatable, intent(out) :: text
        integer, intent(out), optional :: code
        text = "ok"
        if (present(code)) code = self%n
    end subroutine
end module

program optional_tbp_generic_01
    use optional_tbp_generic_01_mod
    type(item) :: a
    character(:), allocatable :: s
    integer :: code
    call a%put(s)
    if (s /= "ok") error stop 1
    call a%put(s, code)
    if (code /= 1) error stop 2
end program
