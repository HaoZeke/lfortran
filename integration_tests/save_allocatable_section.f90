module save_allocatable_section_mod
implicit none
real(8), allocatable, save :: a(:, :), b(:, :)
real(8), allocatable, save :: c(:, :), d(:, :)
real(8), allocatable, save :: e(:, :), f(:, :)
real(8), allocatable, save :: g(:, :)
contains
subroutine update_saved(n, scale)
integer, intent(in) :: n
real(8), intent(in) :: scale
integer :: j
if (.not. allocated(a)) then
    allocate(a(2, n), b(2, n))
    do j = 1, n
        a(1, j) = dble(j)
        a(2, j) = dble(10*j)
        b(1, j) = 1.0d0
        b(2, j) = 2.0d0
    end do
end if
do j = 1, n
    a(1:2, j) = a(1:2, j) + scale*b(1:2, j)
end do
end subroutine update_saved

subroutine update_three(n, scale)
integer, intent(in) :: n
real(8), intent(in) :: scale
integer :: j
if (.not. allocated(c)) then
    allocate(c(3, n), d(3, n))
    do j = 1, n
        c(1, j) = dble(j)
        c(2, j) = dble(10*j)
        c(3, j) = dble(100*j)
        d(1, j) = 1.0d0
        d(2, j) = 2.0d0
        d(3, j) = 3.0d0
    end do
end if
do j = 1, n
    c(1:3, j) = c(1:3, j) + scale*d(1:3, j)
end do
end subroutine update_three

subroutine update_strided(n)
integer, intent(in) :: n
integer :: i, j
if (.not. allocated(e)) then
    allocate(e(6, n), f(6, n))
    do j = 1, n
        do i = 1, 6
            e(i, j) = dble(i)
            f(i, j) = dble(i)
        end do
    end do
end if
do j = 1, n
    e(1:5:2, j) = e(1:5:2, j) + 2.0d0*f(1:5:2, j)
end do
end subroutine update_strided

subroutine update_mapped(n)
integer, intent(in) :: n
integer :: j
integer(1) :: map(n)
if (.not. allocated(g)) then
    allocate(g(2, n))
    do j = 1, n
        g(1, j) = dble(j)
        g(2, j) = dble(10*j)
    end do
end if
do j = 1, n
    map(j) = int(j, 1)
end do
do j = 1, n
    g(1:2, map(j)) = g(1:2, map(j)) + 2.0d0
end do
end subroutine update_mapped

subroutine update_assumed(x, n)
real(8), intent(inout) :: x(:, :)
integer, intent(in) :: n
integer :: j
do j = 1, n
    x(1:2, j) = x(1:2, j) + 2.0d0
end do
end subroutine update_assumed
end module save_allocatable_section_mod

program save_allocatable_section
use save_allocatable_section_mod
implicit none
integer :: j
real(8) :: s
real(8), target :: parent(4, 3)
real(8), pointer :: xp(:, :)
real(8) :: col(4, 2)
call update_saved(4, 2.0d0)
s = 0.0d0
do j = 1, 4
    s = s + a(1, j) + a(2, j)
end do
if (abs(s - 134.0d0) > 1.0d-12) error stop
call update_three(4, 2.0d0)
s = 0.0d0
do j = 1, 4
    s = s + c(1, j) + c(2, j) + c(3, j)
end do
if (abs(s - 1158.0d0) > 1.0d-12) error stop
call update_strided(4)
s = 0.0d0
do j = 1, 4
    s = s + e(1, j) + e(2, j) + e(3, j) + e(4, j) + e(5, j) + e(6, j)
end do
if (abs(s - 156.0d0) > 1.0d-12) error stop
if (abs(e(2, 1) - 2.0d0) > 1.0d-12) error stop
if (abs(e(1, 1) - 3.0d0) > 1.0d-12) error stop
if (abs(e(5, 4) - 15.0d0) > 1.0d-12) error stop
call update_mapped(4)
s = 0.0d0
do j = 1, 4
    s = s + g(1, j) + g(2, j)
end do
if (abs(s - 126.0d0) > 1.0d-12) error stop
parent = 0.0d0
xp => parent(1:4:2, :)
do j = 1, 3
    xp(1:2, j) = xp(1:2, j) + 2.0d0
end do
if (parent(1, 1) /= 2.0d0 .or. parent(3, 1) /= 2.0d0) error stop
if (parent(2, 1) /= 0.0d0 .or. parent(4, 1) /= 0.0d0) error stop
if (parent(1, 3) /= 2.0d0 .or. parent(3, 3) /= 2.0d0) error stop
parent = 0.0d0
call update_assumed(parent(1:4:2, :), 3)
if (parent(1, 2) /= 2.0d0 .or. parent(3, 2) /= 2.0d0) error stop
if (parent(2, 2) /= 0.0d0 .or. parent(4, 2) /= 0.0d0) error stop
col = 0.0d0
col(1, 1:2) = col(1, 1:2) + 3.0d0
if (col(1, 1) /= 3.0d0 .or. col(1, 2) /= 3.0d0) error stop
if (col(2, 1) /= 0.0d0) error stop
print *, 'ok'
end program
