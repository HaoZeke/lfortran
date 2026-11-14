program real_pow_int_01
! Exponents spmpar computes from the IEEE ipmpar table: 1-53, -1021+2,
! 53-1 and 1024-2, with base 2. Each is an exact power of two, so the
! square-and-multiply must match gfortran bit for bit. The exponent is
! a variable so it is not the unrolled constant case.
implicit none
integer :: e
real(8) :: up, down, got
real(8), external :: pow2, pow_base
up = 1.0d0
down = 1.0d0
do e = 1, 12
    up = up*2.0d0
    down = down/2.0d0
    if (pow2(e) /= up) error stop
    if (pow2(-e) /= down) error stop
end do
e = 52
if (pow2(e) /= 4503599627370496.0d0) error stop
if (pow2(-e) * 4503599627370496.0d0 /= 1.0d0) error stop
e = -1019
if (pow2(e) * pow2(1019) /= 1.0d0) error stop
e = 1022
if (pow2(e) * pow2(-1022) /= 1.0d0) error stop
e = 0
if (pow2(e) /= 1.0d0) error stop
e = 4
if (pow_base(3.0d0, e) /= 81.0d0) error stop
e = -3
if (pow_base(5.0d0, e) /= 1.0d0/125.0d0) error stop
got = pow_base(1.5d0, 7)
if (got /= (1.5d0**3)*(1.5d0**3)*1.5d0) error stop
end program

real(8) function pow2(e) result(r)
integer, intent(in) :: e
r = 2.0d0**e
end function

real(8) function pow_base(b, e) result(r)
real(8), intent(in) :: b
integer, intent(in) :: e
r = b**e
end function
