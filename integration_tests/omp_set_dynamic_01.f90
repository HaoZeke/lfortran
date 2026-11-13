program omp_set_dynamic_01
implicit none
integer :: n
call team(2, n)
if (n /= 2) error stop 1
end program

subroutine team(nreq, nteam)
use omp_lib
implicit none
integer, intent(in) :: nreq
integer, intent(out) :: nteam
call omp_set_dynamic(.false.)
call omp_set_num_threads(nreq)
nteam = 0
!$omp parallel
!$omp single
nteam = omp_get_num_threads()
!$omp end single
!$omp end parallel
end subroutine
