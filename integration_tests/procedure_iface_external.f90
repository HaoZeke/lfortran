program procedure_iface_external
implicit none
integer :: n
call driver(callee, n)
if (n /= 42) error stop
contains
    integer(8) function callee(e)
        integer :: e
        callee = e + 41
    end function
end program

subroutine driver(f, n)
integer :: n
integer(8) :: f
external f
interface
    function apply(f) result(r)
        integer(8) :: r
        interface
            function iface(e) result(r)
                integer :: e
                integer(8) :: r
            end function
        end interface
        procedure(iface) :: f
    end function
end interface
n = apply(f)
end subroutine

function apply(f) result(r)
integer(8) :: r
interface
    function iface(e) result(r)
        integer :: e
        integer(8) :: r
    end function
end interface
procedure(iface) :: f
r = f(1)
end function
