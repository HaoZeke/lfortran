program open_newunit_01
    implicit none (external)
    integer :: u, v
    open(newunit=u, file="open_newunit_01.txt", status="replace")
    write(u, *) 7
    close(u)
    open(newunit=u, file="open_newunit_01.txt", status="old")
    read(u, *) v
    close(u, status="delete")
    if (v /= 7) error stop 1
end program open_newunit_01
