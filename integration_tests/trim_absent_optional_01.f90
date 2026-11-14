module trim_absent_optional_01_mod
contains
    pure function optval_character(x, default) result(y)
        character(len=*), intent(in), optional :: x
        character(len=*), intent(in) :: default
        character(len=:), allocatable :: y
        if (present(x)) then
            y = x
        else
            y = default
        end if
    end function

    subroutine save_header(header, trimmed)
        character(len=*), intent(in), optional :: header
        character(len=:), allocatable, intent(out) :: trimmed
        trimmed = optval_character(trim(header), '')
    end subroutine
end module

program trim_absent_optional_01
    use trim_absent_optional_01_mod
    character(len=:), allocatable :: text

    call save_header(trimmed=text)
    if (len(text) /= 0) error stop 1

    call save_header('ab   ', text)
    if (text /= 'ab') error stop 2
end program
