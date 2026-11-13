program sequence_assoc_assumed_size_01
    ! An array element passed to an assumed-size dummy is the element
    ! sequence that starts there.
    implicit none
    integer :: work(6), res
    work = [10, 20, 30, 40, 50, 60]
    call sum2(work(3), res)
    if (res /= 70) error stop 1
contains
    subroutine sum2(a, s)
        integer, intent(in) :: a(*)
        integer, intent(out) :: s
        s = a(1) + a(2)
    end subroutine sum2
end program sequence_assoc_assumed_size_01
