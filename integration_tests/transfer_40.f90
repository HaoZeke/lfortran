program transfer_40
    implicit none
    integer(1) :: src(64, 2)
    integer :: index2, test_block
    src = 1_1
    index2 = 1
    test_block = 16
    call check(transfer(src(index2:index2 + test_block - 1, 2), [0_4]))
contains
    subroutine check(value)
        integer, intent(in) :: value(:)
        if (size(value) /= 4) error stop 1
    end subroutine
end program
