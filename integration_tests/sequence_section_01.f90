module sequence_section_01_mod
contains
    subroutine kernel(n, a)
        integer, value :: n
        real, intent(in) :: a(4, n)
        if (a(1, 1) /= 5.0) error stop 1
        if (a(1, n) /= 17.0) error stop 2
    end subroutine

    subroutine through_contiguous(data)
        real, intent(in), contiguous :: data(:, :)
        call kernel(4, data(:, 2))
    end subroutine
end module

program sequence_section_01
    use sequence_section_01_mod
    real :: data(4, 8)
    integer :: i
    data = reshape([(real(i), i = 1, 32)], [4, 8])
    call kernel(4, data(:, 2))
    call through_contiguous(data)
end program
