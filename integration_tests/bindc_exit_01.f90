module bindc_exit_01_a
contains
    subroutine boom()
        error stop 1
    end subroutine boom
end module bindc_exit_01_a

module bindc_exit_01_b
    use iso_c_binding, only: c_int
    implicit none
    interface
        subroutine exit(status) bind(C, name="exit")
            import c_int
            integer(c_int), value :: status
        end subroutine exit
    end interface
contains
    subroutine run()
        call exit(0_c_int)
    end subroutine run
end module bindc_exit_01_b

program bindc_exit_01
    use bindc_exit_01_a, only: boom
    use bindc_exit_01_b, only: run
    if (.false.) call boom()
    call run()
end program bindc_exit_01
