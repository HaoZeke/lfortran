function t1(value) result(r)
    character(len=1), intent(in) :: value
    character(len=1) :: r
    r = value
end function

function t5(value) result(r)
    character(len=5), intent(in) :: value
    character(len=5) :: r
    r = value
end function
