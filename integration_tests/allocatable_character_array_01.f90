program allocatable_character_array_01
    use allocatable_character_array_01_m
    implicit none
    if (is_alloc()) error stop 1
    call setup(2)
    if (.not. is_alloc()) error stop 2
    if (names(1) /= "test" .or. names(2) /= "test") error stop 3
end program
