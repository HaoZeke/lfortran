! A real element passed to an integer dummy under --implicit-interface.
! The dummy reads the real's bytes. 2.0d0 is 0x4000000000000000, so the
! two integer(4) values are 0 and 1073741824.
subroutine take_real_as_integer(ind)
implicit none
integer :: ind(*)
if (ind(1) /= 0) error stop
if (ind(2) /= 1073741824) error stop
end subroutine

program legacy_real_to_integer_01
implicit none
real(8) :: w(4)
w(2) = 2.0d0
call take_real_as_integer(w(2))
end program
