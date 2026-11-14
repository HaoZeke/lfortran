program matmul_extended_01
    integer, parameter :: xdp = selected_real_kind(18)
    integer, parameter :: qp = selected_real_kind(33)
    integer, parameter :: n = 4
    real(xdp), parameter :: dense(n, n) = reshape(real([1, 2, 0, 0, &
        2, 3, 4, 0, &
        0, 4, 5, 6, &
        0, 0, 6, 7], kind=xdp), [n, n])
    real(xdp), parameter :: vec(n) = real([1, 2, 3, 4], kind=xdp)
    real(xdp), parameter :: y(n) = matmul(dense, vec)
    real(qp), parameter :: dense16(n, n) = reshape(real([1, 2, 0, 0, &
        2, 3, 4, 0, &
        0, 4, 5, 6, &
        0, 0, 6, 7], kind=qp), [n, n])
    real(qp), parameter :: vec16(n) = real([1, 2, 3, 4], kind=qp)
    real(qp), parameter :: y16(n) = matmul(dense16, vec16)
    complex(xdp), parameter :: cy(2) = matmul(reshape([ &
        (1.0_xdp, 0.0_xdp), (2.0_xdp, 0.0_xdp), &
        (3.0_xdp, 0.0_xdp), (4.0_xdp, 0.0_xdp)], [2, 2]), &
        [(1.0_xdp, 0.0_xdp), (2.0_xdp, 0.0_xdp)])
    complex(qp), parameter :: cy16(2) = matmul(reshape([ &
        (1.0_qp, 0.0_qp), (2.0_qp, 0.0_qp), &
        (3.0_qp, 0.0_qp), (4.0_qp, 0.0_qp)], [2, 2]), &
        [(1.0_qp, 0.0_qp), (2.0_qp, 0.0_qp)])
    if (y(1) /= 5.0_xdp .or. y(2) /= 20.0_xdp) error stop 1
    if (y(3) /= 47.0_xdp .or. y(4) /= 46.0_xdp) error stop 2
    if (y16(1) /= 5.0_qp .or. y16(2) /= 20.0_qp) error stop 3
    if (y16(3) /= 47.0_qp .or. y16(4) /= 46.0_qp) error stop 4
    if (cy(1) /= (7.0_xdp, 0.0_xdp) .or. cy(2) /= (10.0_xdp, 0.0_xdp)) error stop 5
    if (cy16(1) /= (7.0_qp, 0.0_qp) .or. cy16(2) /= (10.0_qp, 0.0_qp)) error stop 6
end program
