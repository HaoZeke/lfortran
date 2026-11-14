module optional_array_forward_01_mod
contains
    subroutine forward_char(array, work, reverse)
        character(len=*), intent(inout) :: array(0:)
        character(len=len(array)), intent(out), optional :: work(0:)
        logical, intent(in), optional :: reverse
        if (present(reverse)) then
            if (reverse) then
                call accept_char(array, work)
            else
                call accept_char(array, work)
            end if
        else
            call accept_char(array, work)
        end if
    end subroutine

    subroutine accept_char(array, work)
        character(len=*), intent(inout) :: array(0:)
        character(len=len(array)), intent(out), optional :: work(0:)
        if (present(work)) then
            if (size(work) < 1) error stop 1
            work(0) = array(0)
            array(0) = work(0)
        else
            array(0) = "yyyy"
        end if
    end subroutine

    subroutine forward_int(array, work, reverse)
        integer, intent(inout) :: array(0:)
        integer, intent(out), optional :: work(0:)
        logical, intent(in), optional :: reverse
        if (present(reverse)) then
            if (reverse) then
                call accept_int(array, work)
            else
                call accept_int(array, work)
            end if
        else
            call accept_int(array, work)
        end if
    end subroutine

    subroutine accept_int(array, work)
        integer, intent(inout) :: array(0:)
        integer, intent(out), optional :: work(0:)
        if (present(work)) then
            if (size(work) < 1) error stop 3
            work(0) = array(0)
        else
            array(0) = -5
        end if
    end subroutine
end module

program optional_array_forward_01
    use optional_array_forward_01_mod
    character(len=4) :: text(0:3), text_work(0:1)
    integer :: numbers(0:3), number_work(0:1)

    text = "abcd"
    call forward_char(text, reverse=.true.)
    if (text(0) /= "yyyy") error stop 2

    text = "abcd"
    call forward_char(text, text_work, reverse=.true.)
    if (text(0) /= "abcd") error stop 4
    if (text_work(0) /= "abcd") error stop 5

    numbers = 3
    call forward_int(numbers, reverse=.true.)
    if (numbers(0) /= -5) error stop 6

    numbers = 3
    call forward_int(numbers, number_work, reverse=.true.)
    if (number_work(0) /= 3) error stop 7
end program
