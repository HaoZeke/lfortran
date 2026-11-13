program scalar_partial_sum_01
implicit none
double precision :: total, x
total = 0.0d0
call accumulate(total)
if (abs(total - 6.0d0) > 1.0d-12) error stop
x = 1.0d0
if (abs(bump(x) - 11.0d0) > 1.0d-12) error stop
if (abs(x - 11.0d0) > 1.0d-12) error stop
call midpoint(total)
if (abs(total - 8.0d0) > 1.0d-12) error stop
contains
    subroutine accumulate(res)
        double precision, intent(inout) :: res
        integer :: i
        res = 0.0d0
        do i = 1, 3
            res = res + ident(dble(i))
        end do
    end subroutine

    double precision function ident(t)
        double precision, intent(in) :: t
        ident = t
    end function

    double precision function bump(x)
        double precision, intent(inout) :: x
        x = x + 10.0d0
        bump = x
    end function

    ! A local midpoint is passed to the integrand, then used again. The
    ! integrand updates its argument, and the next evaluation must see that.
    subroutine midpoint(res)
        double precision, intent(out) :: res
        double precision :: centr, t
        centr = 1.0d0
        res = add_one(centr)
        t = centr
        res = res + add_one(t)
        res = res + t
    end subroutine

    double precision function add_one(x)
        double precision, intent(inout) :: x
        x = x + 1.0d0
        add_one = x
    end function
end program
