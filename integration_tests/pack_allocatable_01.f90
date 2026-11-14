program pack_allocatable_01
    implicit none
    integer :: x(4)
    integer(1) :: xi(4)
    logical :: mask(4)
    integer, allocatable :: t(:)
    integer(1), allocatable :: ti(:)
    integer, allocatable :: allv(:)
    x = [1, 2, 3, 4]
    xi = [1_1, 2_1, 3_1, 4_1]
    mask = [.true., .false., .true., .false.]
    t = pack(x, mask)
    if (size(t) /= 2) error stop 1
    if (t(1) /= 1) error stop 2
    if (t(2) /= 3) error stop 3
    ti = pack(xi, mask)
    if (size(ti) /= 2) error stop 4
    if (ti(1) /= 1_1) error stop 5
    if (ti(2) /= 3_1) error stop 6
    allv = pack(x, .true.)
    if (size(allv) /= 4) error stop 7
    if (allv(4) /= 4) error stop 8
end program pack_allocatable_01
