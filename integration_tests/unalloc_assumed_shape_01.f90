module unalloc_assumed_shape_01_mod
contains
    subroutine fill(index_save, data_save, j, half_nnz, symmetry, is_pattern)
        integer, intent(inout) :: index_save(:, :)
        real, intent(inout) :: data_save(:)
        integer, intent(inout) :: j
        integer, intent(in) :: half_nnz, symmetry
        logical, intent(in) :: is_pattern
        integer :: i
        if (.not. is_pattern) then
            do i = 1, half_nnz
                data_save(j) = data_save(i)
                j = j + 1
            end do
        end if
    end subroutine
end module

program unalloc_assumed_shape_01
    use unalloc_assumed_shape_01_mod
    integer, allocatable :: idx(:, :)
    real, allocatable :: data(:)
    integer :: j
    allocate(idx(2, 4))
    idx = 1
    j = 3
    call fill(idx, data, j, 2, 1, .true.)
    if (j /= 3) error stop 1
    if (allocated(data)) error stop 2
end program
