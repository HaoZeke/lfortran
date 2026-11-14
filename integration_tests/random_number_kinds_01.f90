module random_number_kinds_01_mod
contains
    subroutine fill_real10()
        real(10) :: c(2)
        call random_number(c)
    end subroutine
end module

program random_number_kinds_01
    use random_number_kinds_01_mod
    type t
        sequence
        real(8) :: x
        integer(2) :: s
    end type
    type(t) :: a
    real(8) :: b(5, 5)
    integer :: i, j
    a%s = 7_2
    a%x = 0.0_8
    call fill_real10()
    call random_number(a%x)
    if (a%s /= 7_2) error stop 1
    if (a%x < 0.0_8 .or. a%x >= 1.0_8) error stop 2
    call random_number(b)
    do i = 1, 5
        do j = 1, 5
            if (b(i, j) < 0.0_8 .or. b(i, j) >= 1.0_8) error stop 3
        end do
    end do
end program
