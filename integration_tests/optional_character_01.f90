! An omitted optional character is absent. present() is false, and the
! dummy is not accessed.
module optional_character_01_m
contains
subroutine s(flag, text)
    integer, intent(out) :: flag
    character(len=*), optional, intent(in) :: text
    if (present(text)) then
        flag = len(text)
    else
        flag = 0
    end if
end subroutine
end module

program optional_character_01
    use optional_character_01_m
    implicit none
    integer :: flag
    call s(flag)
    if (flag /= 0) error stop 1
    call s(flag, "abcd")
    if (flag /= 4) error stop 2
end program
