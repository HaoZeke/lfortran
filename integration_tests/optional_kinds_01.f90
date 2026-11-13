! An absent optional is a null pointer: a callback, an allocatable, a
! pointer, a VALUE dummy and an ordinary argument. present(), allocated()
! and associated() test that pointer. There is no extra presence argument.
program optional_kinds_01
    implicit none
    integer :: flag
    real, allocatable :: heap(:)
    real, pointer :: p

    call use_cb(flag=flag)
    if (flag /= 0) error stop 1
    call use_cb(set4, flag)
    if (flag /= 4) error stop 2

    call use_alloc(flag=flag)
    if (flag /= 0) error stop 3
    call use_alloc(heap, flag)
    if (flag /= 0) error stop 4
    allocate(heap(1))
    call use_alloc(heap, flag)
    if (flag /= 1) error stop 5

    call use_ptr(flag=flag)
    if (flag /= 0) error stop 6
    p => null()
    call use_ptr(p, flag)
    if (flag /= 0) error stop 7
    allocate(p)
    call use_ptr(p, flag)
    if (flag /= 1) error stop 8

    call use_value(flag=flag)
    if (flag /= 0) error stop 9
    call use_value(6, flag)
    if (flag /= 6) error stop 10

    call use_real(flag=flag)
    if (flag /= 0) error stop 11
    call use_real(1.0, flag)
    if (flag /= 1) error stop 12
contains
    subroutine set4(flag)
        integer, intent(out) :: flag
        flag = 4
    end subroutine

    subroutine use_cb(fun, flag)
        interface
            subroutine fun(flag)
                integer, intent(out) :: flag
            end subroutine
        end interface
        optional fun
        integer, intent(out) :: flag
        if (present(fun)) then
            call fun(flag)
        else
            flag = 0
        end if
    end subroutine

    subroutine use_alloc(x, flag)
        real, allocatable, optional, intent(in) :: x(:)
        integer, intent(out) :: flag
        if (.not. present(x)) then
            flag = 0
        else if (allocated(x)) then
            flag = 1
        else
            flag = 0
        end if
    end subroutine

    subroutine use_ptr(x, flag)
        real, pointer, optional, intent(in) :: x
        integer, intent(out) :: flag
        if (.not. present(x)) then
            flag = 0
        else if (associated(x)) then
            flag = 1
        else
            flag = 0
        end if
    end subroutine

    subroutine use_value(x, flag)
        integer, optional, value, intent(in) :: x
        integer, intent(out) :: flag
        if (present(x)) then
            flag = x
        else
            flag = 0
        end if
    end subroutine

    subroutine use_real(x, flag)
        real, optional, intent(in) :: x
        integer, intent(out) :: flag
        if (present(x)) then
            flag = 1
        else
            flag = 0
        end if
    end subroutine
end program
