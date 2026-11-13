program present_char_01
    ! present() of an optional scalar and of an optional character.
    implicit none
    call show()
    call show(3)
    call note()
    call note("note")
contains
    subroutine show(n)
        integer, intent(in), optional :: n
        if (present(n)) then
            if (n /= 3) error stop 1
        end if
    end subroutine show

    subroutine note(message)
        character(len=*), intent(in), optional :: message
        if (present(message)) then
            if (message /= "note") error stop 2
        end if
    end subroutine note
end program present_char_01
