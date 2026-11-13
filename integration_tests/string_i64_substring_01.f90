subroutine i64_substr_scalar(s, n, last)
implicit none
character(len=*), intent(in) :: s
integer(kind=8), intent(in) :: n
integer, intent(out) :: last
last = ichar(s(n:n))
end subroutine

subroutine i64_substr_array(a, m, n, last)
implicit none
integer, intent(in) :: m
character(len=*), intent(in) :: a(m)
integer(kind=8), intent(in) :: n
integer, intent(out) :: last
last = ichar(a(m)(n:n))
end subroutine
