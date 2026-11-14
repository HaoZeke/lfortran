program mod_unit_01
implicit none
real(8) :: x, y, z
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
! The zero keeps the sign of the dividend: mod(-2, 1) and
! mod(-2**53, 1) are -0, and mod(-0, 1) stays -0.
x = 2.0d0**53
y = mod(x, one)
if (transfer(y, 0_8) /= transfer(0.0d0, 0_8)) error stop
y = mod(-x, one)
if (transfer(y, 0_8) /= transfer(-0.0d0, 0_8)) error stop
y = mod(-2.0d0, one)
if (transfer(y, 0_8) /= transfer(-0.0d0, 0_8)) error stop
y = mod(-2.0d0, -one)
if (transfer(y, 0_8) /= transfer(-0.0d0, 0_8)) error stop
y = mod(-0.0d0, one)
if (transfer(y, 0_8) /= transfer(-0.0d0, 0_8)) error stop
y = mod(2.0d0, one)
if (transfer(y, 0_8) /= transfer(0.0d0, 0_8)) error stop
! inf and nan. Both sides of the division are run-time zeros so
! the source is valid. gfortran's result is the indefinite NaN.
z = 0.0d0
y = mod(1.0d0/z, one)
if (transfer(y, 0_8) /= -2251799813685248_8) error stop
y = mod(-1.0d0/z, one)
if (transfer(y, 0_8) /= -2251799813685248_8) error stop
y = mod(z/z, one)
if (transfer(y, 0_8) /= -2251799813685248_8) error stop
end program
