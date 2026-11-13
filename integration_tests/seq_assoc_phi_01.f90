! An array element passed to an array dummy is a sequence association.
! The section is materialized on each side of a branch, and the two
! pointers join. The sums are the in-order values.
subroutine add_one(n, a)
implicit none
integer :: n
real :: a(n)
integer :: i
do i = 1, n
    a(i) = a(i) + 1.0
end do
end subroutine add_one

program seq_assoc_phi_01
implicit none
real :: w(16)
integer :: i, icon
w = 1.0
icon = 3
if (icon > 0) then
    call add_one(8, w(icon))
else
    call add_one(4, w(1))
end if
if (abs(w(2) - 1.0) > 1.0e-6) error stop
if (abs(w(3) - 2.0) > 1.0e-6) error stop
if (abs(w(10) - 2.0) > 1.0e-6) error stop
if (abs(w(11) - 1.0) > 1.0e-6) error stop
do i = 1, 16
    w(i) = real(i)
end do
if (icon < 0) then
    call add_one(4, w(1))
else
    call add_one(8, w(icon))
end if
if (abs(w(3) - 4.0) > 1.0e-6) error stop
if (abs(w(10) - 11.0) > 1.0e-6) error stop
end program
