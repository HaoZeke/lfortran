program open_newunit_01
    ! open(newunit=) is a specifier, not an external procedure.
    implicit none (external)
    integer :: u
    open(newunit=u, status='scratch')
    if (u == 0) error stop 1
    close(u)
end program open_newunit_01
