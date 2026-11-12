subroutine take(a)
    character(len=1), intent(in) :: a(2)
    if (a(1) /= "a" .or. a(2) /= "b") error stop 1
end subroutine

program character_array_01
    implicit none
    character(len=1) :: a(2)
    a = ["a", "b"]
    call take(a)
end program
