! present() of an optional procedure. LLVM 16 uses opaque pointers, so
! present() must not ask a pointer for its element type. --fast is the
! flag f90wrap passes when this crashed.
module present_fast_01_m
    implicit none
    abstract interface
        subroutine iface(x)
            integer, intent(inout) :: x
        end subroutine iface
    end interface
contains
    subroutine add1(x)
        integer, intent(inout) :: x
        x = x + 1
    end subroutine add1

    subroutine callo(x, p)
        integer, intent(inout) :: x
        procedure(iface), optional :: p
        if (present(p)) then
            call p(x)
        else
            x = -x
        end if
    end subroutine callo
end module present_fast_01_m

program present_fast_01
    use present_fast_01_m
    implicit none
    integer :: i
    i = 4
    call callo(i, add1)
    if (i /= 5) error stop "present procedure was not called"
    call callo(i)
    if (i /= -5) error stop "absent procedure was treated as present"
    print *, "ok"
end program present_fast_01
