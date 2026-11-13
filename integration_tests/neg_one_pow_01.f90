program neg_one_pow_01
implicit none
integer :: k, s1, s2
integer(8) :: e8, p8
s1 = 0
s2 = 0
do k = 0, 30
    s1 = s1 + (-1)**(k / 2)
    s2 = s2 + (-1)**k
end do
if (s1 /= 1) error stop
if (s2 /= 1) error stop
if ((-1)**(-3) /= -1) error stop
if ((-1)**(-4) /= 1) error stop
if (1**(-2) /= 1) error stop
e8 = -5
p8 = (-1_8)**e8
if (p8 /= -1_8) error stop
e8 = 4
p8 = (-1_8)**e8
if (p8 /= 1_8) error stop
end program
