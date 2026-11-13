! A complex array passed to an integer dummy under --implicit-interface.
! `(1.0d0, 0.0d0)` is `0x3ff0000000000000` followed by a zero real, so
! the four integer(4) values are 0, 1072693248, 0, 0.
subroutine take_complex_as_integer(ind)
implicit none
integer :: ind(*)
if (ind(1) /= 0) error stop
if (ind(2) /= 1072693248) error stop
if (ind(3) /= 0) error stop
if (ind(4) /= 0) error stop
end subroutine

subroutine wrap_complex_index(c)
implicit none
complex(8) :: c(*)
call take_complex_as_integer(c)
end subroutine

program legacy_complex_to_integer_01
implicit none
complex(8) :: c(1)
c(1) = (1.0d0, 0.0d0)
call wrap_complex_index(c)
end program
