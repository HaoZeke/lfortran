! Each ENTRY returns its own value. h(1.5) is 6, not 0.
function f(x) result(r)
    double precision, intent(in) :: x
    double precision :: r, h
    integer :: g
    r = 2 * x
    return
entry g(x)
    g = int(3 * x)
    return
entry h(x)
    h = 4 * x
end function

program entry_32
    implicit none
    interface
        double precision function f(x) result(r)
            double precision, intent(in) :: x
        end function
        integer function g(x)
            double precision, intent(in) :: x
        end function
        double precision function h(x)
            double precision, intent(in) :: x
        end function
    end interface
    if (abs(f(1.5d0) - 3.0d0) > 1d-12) error stop 1
    if (g(2.0d0) /= 6) error stop 2
    if (abs(h(1.5d0) - 6.0d0) > 1d-12) error stop 3
end program
