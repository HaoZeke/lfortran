program std_legacy_free_form
implicit none
character(len=11) :: data_type
data_type = 'CONSTRAINT'
! The comparison is free-form and longer than 72 columns. --std=legacy
! must not parse this .f90 file as fixed form, or the literal is cut.
        if (data_type .eq. 'Constraint' .or. data_type .eq. 'CONSTRAINT') then
    print *, 'ok'
else
    error stop
end if
end program
