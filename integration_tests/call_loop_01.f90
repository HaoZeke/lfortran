program call_loop_01
implicit none
double precision :: s, x
integer :: j
s = 0.0d0
do j = 1, 5
    s = s + ident(dble(j))
end do
if (abs(s - 15.0d0) > 1.0d-12) error stop
x = 1.0d0
do j = 1, 4
    x = add_one(x)
end do
if (abs(x - 5.0d0) > 1.0d-12) error stop
contains
    double precision function ident(t)
        double precision, intent(in) :: t
        ident = t
    end function

    double precision function add_one(t)
        double precision, intent(inout) :: t
        t = t + 1.0d0
        add_one = t
    end function
end program
