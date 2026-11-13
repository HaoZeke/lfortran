program allocatable_dt_array_ctor_01
    ! An array constructor assigned to an unallocated allocatable array
    ! allocates the left hand side.
    implicit none
    type :: testsuite_type
        integer :: n
    end type testsuite_type
    type(testsuite_type), allocatable :: testsuites(:)

    testsuites = [new_testsuite(1), new_testsuite(2)]
    if (.not. allocated(testsuites)) error stop 1
    if (size(testsuites) /= 2) error stop 2
    if (testsuites(1)%n /= 1) error stop 3
    if (testsuites(2)%n /= 2) error stop 4
contains
    function new_testsuite(n) result(self)
        integer, intent(in) :: n
        type(testsuite_type) :: self
        self%n = n
    end function new_testsuite
end program allocatable_dt_array_ctor_01
