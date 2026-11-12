! An undeclared ENTRY result is typed by the implicit rules, not by the
! host function's result. `h` is default real; `iadd` is default integer.
function f(x) result(r)
    double precision, intent(in) :: x
    double precision :: r
    integer :: g
    r = 2 * x
    return
entry g(x)
    g = int(3 * x)
    return
entry h(x)
    h = 4 * x
end function

real function host(x)
    real :: x
    host = x
    return
entry iadd(x)
    iadd = 3
    return
end function

program entry_33
    implicit none
    interface
        double precision function f(x) result(r)
            double precision, intent(in) :: x
        end function
        integer function g(x)
            double precision, intent(in) :: x
        end function
        real function h(x)
            double precision, intent(in) :: x
        end function
        real function host(x)
            real :: x
        end function
        integer function iadd(x)
            real :: x
        end function
    end interface
    if (abs(f(1.5d0) - 3.0d0) > 1d-12) error stop 1
    if (g(1.5d0) /= 4) error stop 2
    if (abs(h(1.5d0) - 6.0) > 1e-5) error stop 3
    if (abs(host(1.5) - 1.5) > 1e-5) error stop 4
    if (iadd(1.0) /= 3) error stop 5
end program
