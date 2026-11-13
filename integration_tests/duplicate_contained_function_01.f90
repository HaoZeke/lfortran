subroutine duplicate_contained_function_01_s
contains
    function f(e) result(r)
        integer :: e, r
        r = e + 1
    end function
    function f(e) result(r)
        integer :: e, r
        r = e + 1
    end function
end subroutine

program duplicate_contained_function_01
    implicit none
    interface
        subroutine duplicate_contained_function_01_s()
        end subroutine
    end interface
    call duplicate_contained_function_01_s()
end program
