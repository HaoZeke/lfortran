program realloc_unalloc_array_01
    ! Intrinsic assignment allocates an unallocated allocatable array.
    implicit none
    integer(1), allocatable :: bytes(:)
    real, allocatable :: src(:), dst(:)
    character(len=1), allocatable :: letters(:)
    type :: item
        integer :: n
    end type item
    type(item), allocatable :: items(:)

    bytes = [5_1, 4_1, 3_1]
    if (size(bytes) /= 3) error stop 1
    if (bytes(2) /= 4_1) error stop 2

    allocate(src(2))
    src = [1.0, 2.0]
    dst = src
    if (size(dst) /= 2) error stop 3
    if (dst(1) /= 1.0) error stop 4

    letters = ["x", "y"]
    if (size(letters) /= 2) error stop 5
    if (letters(1) /= "x") error stop 6

    items = [item(3), item(4)]
    if (size(items) /= 2) error stop 7
    if (items(2)%n /= 4) error stop 8
end program realloc_unalloc_array_01
