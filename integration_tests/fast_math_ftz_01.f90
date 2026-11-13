program fast_math_ftz_01
implicit none
double precision :: x
double precision :: half_down
external half_down
! The product is computed in C, so this compiler cannot fold it.
! Half of tiny() is subnormal. Fast math flushes it to zero.
x = tiny(1.0d0)
x = half_down(x)
if (x /= 0.0d0) error stop
end program
