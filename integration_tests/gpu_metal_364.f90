program gpu_metal_364
! Assigning a section to an allocatable component allocates the component.
implicit none
type tt
    real, allocatable :: v(:)
end type
real :: c(6)
type(tt) :: t(3)
integer :: i

c = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
allocate(t(1)%v(3), t(3)%v(3))
do concurrent (i = 1:2)
    t(i)%v = c(i:i+2)
end do
if (.not. allocated(t(2)%v)) error stop 1
if (any(t(2)%v /= c(2:4))) error stop 2

end program
