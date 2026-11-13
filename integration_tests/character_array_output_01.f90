! Each element of a character array is the transfer of the matching
! integer element, from the start of that element.
subroutine fill(c, o)
    character :: c(3)
    integer(1), intent(in) :: o(3)
    integer :: i
    do i = 1, 3
        c(i) = transfer(o(i), c(i))
    end do
end subroutine

program character_array_output_01
    implicit none
    character :: c(3)
    integer(1) :: o(3)
    o(1) = iachar('a')
    o(2) = iachar('b')
    o(3) = iachar('c')
    call fill(c, o)
    if (c(1) /= 'a' .or. c(2) /= 'b' .or. c(3) /= 'c') error stop
end program
