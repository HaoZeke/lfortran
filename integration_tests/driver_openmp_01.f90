program driver_openmp_01
use omp_lib
implicit none
integer :: n
n = omp_get_num_threads()
if (n < 1) error stop 1
print *, "ok"
end program
