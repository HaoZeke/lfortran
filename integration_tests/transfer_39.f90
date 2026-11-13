program transfer_39
    implicit none

    type :: key_type
        integer(1), allocatable :: value(:)
    end type key_type

    type(key_type) :: key
    character(len=:), allocatable :: text
    integer(8) :: n

    key%value = [97_1, 98_1, 99_1, 100_1]
    n = 4
    allocate(character(len=n) :: text)
    text(1:n) = transfer(key%value, text)
    if (text /= "abcd") error stop 1
end program transfer_39
