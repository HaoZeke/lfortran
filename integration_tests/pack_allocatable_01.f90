program pack_allocatable_01
    implicit none
    integer :: a(4)
    integer :: v(3)
    logical :: m(4)
    integer, allocatable :: b(:)
    type :: string_t
        character(len=:), allocatable :: s
    end type string_t
    type(string_t), allocatable :: files(:), src(:)
    logical :: is_source(3)
    character(len=4) :: names(3)
    character(len=4), allocatable :: picked(:)

    a = [1, 2, 3, 4]
    m = [.true., .false., .true., .false.]
    b = pack(a, m)
    if (size(b) /= 2) error stop 1
    if (b(1) /= 1 .or. b(2) /= 3) error stop 2

    b = pack(a, .true.)
    if (size(b) /= 4) error stop 3
    if (any(b /= a)) error stop 4

    b = pack(a, .false.)
    if (size(b) /= 0) error stop 5

    v = 0
    b = pack(a, m, v)
    if (size(b) /= 3) error stop 6
    if (b(1) /= 1 .or. b(2) /= 3 .or. b(3) /= 0) error stop 7

    allocate(files(3))
    files(1)%s = "a.f90"
    files(2)%s = "a.txt"
    files(3)%s = "b.f90"
    is_source = [.true., .false., .true.]
    src = pack(files, is_source)
    if (size(src) /= 2) error stop 8
    if (src(1)%s /= "a.f90" .or. src(2)%s /= "b.f90") error stop 9

    names = [character(len=4) :: "a.f9", "b.tx", "c.f9"]
    picked = pack(names, [.true., .false., .true.])
    if (size(picked) /= 2) error stop 10
    if (picked(1) /= "a.f9" .or. picked(2) /= "c.f9") error stop 11
end program pack_allocatable_01
