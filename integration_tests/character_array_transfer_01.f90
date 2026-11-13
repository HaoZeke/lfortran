! transfer() with an array section as the mold has that section's size.
! o(i, :) is two elements, and so is transfer(c(i), o(i, :)).
subroutine take(c, o, m, n)
    integer, intent(in) :: m, n
    character(len=2), intent(in) :: c(m)
    integer(1), intent(out) :: o(m, n)
    integer :: i
    do i = 1, m
        o(i, :) = transfer(c(i), o(i, :))
    end do
end subroutine

subroutine take1(c, o, m, n)
    integer, intent(in) :: m, n
    character(len=1), intent(in) :: c(m)
    integer(1), intent(out) :: o(m, n)
    integer :: i
    do i = 1, m
        o(i, :) = transfer(c(i), o(i, :))
    end do
end subroutine

program character_array_transfer_01
    implicit none
    character(len=2) :: c(2)
    integer(1) :: o(2, 2)
    character(len=1) :: c1(2)
    integer(1) :: o1(2, 1)
    c(1) = 'ab'
    c(2) = 'cd'
    call take(c, o, 2, 2)
    if (o(1, 1) /= iachar('a') .or. o(1, 2) /= iachar('b')) error stop 1
    if (o(2, 1) /= iachar('c') .or. o(2, 2) /= iachar('d')) error stop 2
    c1(1) = 'a'
    c1(2) = 'b'
    call take1(c1, o1, 2, 1)
    if (o1(1, 1) /= iachar('a') .or. o1(2, 1) /= iachar('b')) error stop 3
end program
