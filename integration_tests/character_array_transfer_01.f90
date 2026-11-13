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
    block
        character(len=15) :: cs(2)
        integer(1) :: os(2, 15)
        integer :: i, j
        character(len=15) :: src(2)
        src(1) = 'abcdeabcdeabcde'
        src(2) = 'ABCDEABCDEABCDE'
        do i = 1, 2
            do j = 1, 15
                os(i, j) = iachar(src(i)(j:j))
            end do
        end do
        call take_star(cs, os, 2, 15)
        if (cs(1) /= src(1) .or. cs(2) /= src(2)) error stop 4
    end block
end program

subroutine take_star(c, o, m, n)
    integer, intent(in) :: m, n
    character(*), intent(out) :: c(m)
    integer(1), intent(in) :: o(m, n)
    integer :: i
    do i = 1, m
        c(i) = transfer(o(i, :), c(i))
    end do
end subroutine
