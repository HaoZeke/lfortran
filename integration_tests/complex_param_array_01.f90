program complex_param_array_01
    integer, parameter :: xdp = selected_real_kind(18)
    integer, parameter :: qp = selected_real_kind(30)
    integer, parameter :: m1 = 1, n1 = 2, m2 = 2, n2 = 3
    complex(xdp), parameter :: ex(3) = [1, 2, 3]
    complex(qp), parameter :: eq(3) = [1, 2, 3]
    complex(xdp), dimension(m1*m2, n1*n2), parameter :: kx &
        = transpose(reshape([1, 2, 3, 2, 4, 6, 2, 4, 6, 4, 8, 12], [m2*n2, m1*n1]))
    complex(qp), dimension(m1*m2, n1*n2), parameter :: kq &
        = transpose(reshape([1, 2, 3, 2, 4, 6, 2, 4, 6, 4, 8, 12], [m2*n2, m1*n1]))
    complex(xdp) :: a(m1, n1), b(m2, n2), c(m1*m2, n1*n2)
    integer :: i, j, m, n

    if (real(ex(1)) /= 1 .or. aimag(ex(1)) /= 0) error stop 1
    if (real(ex(2)) /= 2 .or. aimag(ex(2)) /= 0) error stop 2
    if (real(ex(3)) /= 3 .or. aimag(ex(3)) /= 0) error stop 3
    if (real(eq(1)) /= 1 .or. aimag(eq(1)) /= 0) error stop 4
    if (real(eq(2)) /= 2 .or. aimag(eq(2)) /= 0) error stop 5
    if (real(eq(3)) /= 3 .or. aimag(eq(3)) /= 0) error stop 6

    do j = 1, n1
        do i = 1, m1
            a(i, j) = i*j
        end do
    end do
    do j = 1, n2
        do i = 1, m2
            b(i, j) = i*j
        end do
    end do
    do n = 1, n1
        do m = 1, m1
            c((m - 1)*m2 + 1:m*m2, (n - 1)*n2 + 1:n*n2) = a(m, n)*b
        end do
    end do
    if (any(abs(c - kx) > 1.0e-6_xdp)) error stop 7
    if (any(abs(c - kq) > 1.0e-6_qp)) error stop 8
end program
