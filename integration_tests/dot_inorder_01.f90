! Strict product reduction. Pairs may be multiplied together, then added
! in order: the bits match the scalar sum, including a strided factor.
program dot_inorder_01
implicit none
integer :: n, i
double precision :: a(9), b(9), col(3, 9), s, ref
do i = 1, 9
    a(i) = sin(dble(i) * 0.37d0)
    b(i) = cos(dble(i * i) * 0.11d0)
    col(1, i) = a(i)
    col(2, i) = a(i) + 0.5d0
    col(3, i) = a(i) - 0.25d0
end do
do n = 1, 9
    s = 0.0d0
    do i = 1, n
        s = s + a(i) * b(i)
    end do
    ref = 0.0d0
    if (n >= 1) ref = ref + a(1) * b(1)
    if (n >= 2) ref = ref + a(2) * b(2)
    if (n >= 3) ref = ref + a(3) * b(3)
    if (n >= 4) ref = ref + a(4) * b(4)
    if (n >= 5) ref = ref + a(5) * b(5)
    if (n >= 6) ref = ref + a(6) * b(6)
    if (n >= 7) ref = ref + a(7) * b(7)
    if (n >= 8) ref = ref + a(8) * b(8)
    if (n >= 9) ref = ref + a(9) * b(9)
    if (transfer(s, 0_8) /= transfer(ref, 0_8)) error stop
    s = 0.0d0
    do i = 1, n
        s = s + col(2, i) * b(i)
    end do
    ref = 0.0d0
    if (n >= 1) ref = ref + col(2, 1) * b(1)
    if (n >= 2) ref = ref + col(2, 2) * b(2)
    if (n >= 3) ref = ref + col(2, 3) * b(3)
    if (n >= 4) ref = ref + col(2, 4) * b(4)
    if (n >= 5) ref = ref + col(2, 5) * b(5)
    if (n >= 6) ref = ref + col(2, 6) * b(6)
    if (n >= 7) ref = ref + col(2, 7) * b(7)
    if (n >= 8) ref = ref + col(2, 8) * b(8)
    if (n >= 9) ref = ref + col(2, 9) * b(9)
    if (transfer(s, 0_8) /= transfer(ref, 0_8)) error stop
end do
end program
