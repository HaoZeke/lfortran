module optional_tbp_generic_fn_01_mod
    type :: item
        real :: value = 1.0
        real :: uncertainty = 0.1
    contains
        procedure :: to_real_sp
        generic :: to_real => to_real_sp
    end type
contains
    elemental pure real function to_real_sp(self, mold, uncertainty) result(r)
        class(item), intent(in) :: self
        real, intent(in) :: mold
        logical, intent(in), optional :: uncertainty
        if (present(uncertainty)) then
            if (uncertainty) then
                r = self%uncertainty
            else
                r = self%value
            end if
        else
            r = self%value
        end if
    end function to_real_sp
end module optional_tbp_generic_fn_01_mod

program optional_tbp_generic_fn_01
    use optional_tbp_generic_fn_01_mod
    type(item) :: a
    real :: x
    x = a%to_real(1.0)
    if (abs(x - 1.0) > 1.0e-6) error stop 1
    x = a%to_real(1.0, .true.)
    if (abs(x - 0.1) > 1.0e-6) error stop 2
end program optional_tbp_generic_fn_01
