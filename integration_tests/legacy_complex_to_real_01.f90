! A complex array passed to a real dummy under --implicit-interface.
! The dummy reads the complex value as two reals.
subroutine take_complex_as_real(w)
implicit none
real(8) :: w(*)
if (w(1) /= 1.5d0) error stop
if (w(2) /= -2.5d0) error stop
end subroutine

subroutine wrap_complex(c)
implicit none
complex(8) :: c(*)
call take_complex_as_real(c)
end subroutine

program legacy_complex_to_real_01
implicit none
complex(8) :: c(1)
c(1) = (1.5d0, -2.5d0)
call wrap_complex(c)
end program
