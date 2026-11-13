program prog_ext_sub
implicit none
type :: t
    procedure(__p_iface_implicit_), pointer :: p
end type t
type(t) :: a
integer(4) :: i
integer(4) :: y
external :: __p_iface_implicit_
integer(4), external :: f_
external :: g_
external :: sub_
i = 1
y = f_(1)
call g_(i)
a%p => sub_
call a%p(1)
end program prog_ext_sub
