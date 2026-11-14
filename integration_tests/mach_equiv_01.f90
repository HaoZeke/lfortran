program mach_equiv_01
! The integer pair overlays one static double, and the second call still
! sees it. 0, 1048576 is the little-endian spelling of 2**(-1022),
! which is d1mach(1).
implicit none
integer(8) :: bits
double precision, external :: tiny_pair
if (transfer(tiny_pair(), bits) /= int(z'10000000000000', 8)) error stop
if (transfer(tiny_pair(), bits) /= int(z'10000000000000', 8)) error stop
end program

double precision function tiny_pair()
implicit none
integer :: lo(2), ready
double precision :: block(1)
save lo, ready
equivalence (block(1), lo(1))
if (ready /= 1) then
    lo(1) = 0
    lo(2) = 1048576
    ready = 1
end if
tiny_pair = block(1)
end function
