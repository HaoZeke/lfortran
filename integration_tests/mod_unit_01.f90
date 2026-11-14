program mod_unit_01
implicit none
real(8) :: x, y
real(8), parameter :: one = 1.0d0
x = 1.5d0
y = mod(x, one)
if (y /= 0.5d0) error stop
x = -1.5d0
y = mod(x, one)
if (y /= -0.5d0) error stop
x = 100.25d0
y = mod(x, one)
if (y /= 0.25d0) error stop
x = -100.25d0
y = mod(x, one)
if (y /= -0.25d0) error stop
x = 1.5d0
y = mod(x, -one)
if (y /= 0.5d0) error stop
x = -1.5d0
y = mod(x, -one)
if (y /= -0.5d0) error stop
! A divisor that is not ±1 stays on fmod. 5/2.5 and -5.5/2 are exact.
x = 5.0d0
y = mod(x, 2.5d0)
if (y /= 0.0d0) error stop
x = -5.5d0
y = mod(x, 2.0d0)
if (y /= -1.5d0) error stop
! |x| past 2**52 has no fractional part, so mod(x, 1) is zero.
x = 2.0d0**53
y = mod(x, one)
if (y /= 0.0d0) error stop
end program
