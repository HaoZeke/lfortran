module min_int64_associate_01_mod
    implicit none
    type :: sellc
        integer(8) :: nrows = 5_8
        integer :: chunk_size = 2
    end type sellc
contains
    subroutine conv(s, nsteps)
        type(sellc), intent(out) :: s
        integer, intent(out) :: nsteps
        integer :: i, j
        s%nrows = 5_8
        s%chunk_size = 2
        nsteps = 0
        associate (nrows => s%nrows, chunk_size => s%chunk_size)
            do i = 1, int(nrows), chunk_size
                do j = i, min(i + chunk_size - 1, nrows)
                    nsteps = nsteps + 1
                end do
            end do
        end associate
    end subroutine conv
end module min_int64_associate_01_mod

program min_int64_associate_01
    use min_int64_associate_01_mod
    implicit none
    type(sellc) :: s
    integer :: nsteps
    call conv(s, nsteps)
    if (s%nrows /= 5_8) error stop 1
    if (nsteps /= 5) error stop 2
end program min_int64_associate_01
