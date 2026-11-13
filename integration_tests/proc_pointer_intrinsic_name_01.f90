program proc_pointer_intrinsic_name_01
    ! A procedure pointer named like an intrinsic is still that pointer.
    implicit none
    abstract interface
        function cos_t(x)
            real, intent(in) :: x
            real :: cos_t
        end function cos_t
    end interface
    procedure(cos_t), pointer :: ccos
    ccos => one
    if (abs(ccos(0.0) - 1.0) > 1.0e-6) error stop 1
contains
    function one(x)
        real, intent(in) :: x
        real :: one
        one = 1.0 + 0.0*x
    end function one
end program proc_pointer_intrinsic_name_01
