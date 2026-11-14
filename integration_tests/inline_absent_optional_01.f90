module inline_absent_optional_01_mod
contains
    pure function opt(x, default) result(y)
        real, intent(in), optional :: x
        real, intent(in) :: default
        real :: y
        if (present(x)) then
            y = x
        else
            y = default
        end if
    end function

    pure function foo(x) result(z)
        real, intent(in), optional :: x
        real :: z
        z = opt(x, 2.0)
    end function
end module

program inline_absent_optional_01
    use inline_absent_optional_01_mod
    if (foo() /= 2.0) error stop 1
    if (foo(1.0) /= 1.0) error stop 2
end program
