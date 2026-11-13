program openmp_cond_01
    implicit none
    integer :: flag
    call uses_openmp(flag)
    if (flag /= 1) error stop 1
end program

subroutine uses_openmp(flag)
    implicit none
    integer, intent(out) :: flag
    flag = 0
!$ flag = 1
end subroutine
