subroutine add_ends(n, v, s)
    integer, intent(in) :: n
    real, intent(in) :: v(n)
    real, intent(out) :: s
    s = v(1) + v(n)
end subroutine add_ends

program allocatable_reshape_01
    implicit none
    real :: a(2, 2)
    real, allocatable :: ap(:, :)
    real :: col
    real :: src(4)
    real, allocatable :: row(:)
    a = reshape([1.0, 2.0, 3.0, 4.0], [2, 2])
    ap = reshape(a, [2, 2])
    if (ap(1, 1) /= 1.0) error stop 1
    if (ap(2, 1) /= 2.0) error stop 2
    if (ap(1, 2) /= 3.0) error stop 3
    if (ap(2, 2) /= 4.0) error stop 4
    call add_ends(2, ap(:, 1), col)
    if (abs(col - 3.0) > 1.0e-6) error stop 5
    src = [1.0, 2.0, 3.0, 4.0]
    row = reshape(src, [4])
    if (row(1) /= 1.0) error stop 6
    if (row(4) /= 4.0) error stop 7
    block
        integer :: spack(2), order(2)
        real, allocatable :: packed(:, :)
        spack = [2, 2]
        order = [2, 1]
        packed = reshape(a, shape=spack, order=order)
        if (packed(1, 1) /= 1.0) error stop 8
        if (packed(1, 2) /= 2.0) error stop 9
        if (packed(2, 1) /= 3.0) error stop 10
        if (packed(2, 2) /= 4.0) error stop 11
        call add_ends(2, packed(:, 1), col)
        if (abs(col - 4.0) > 1.0e-6) error stop 12
    end block
end program allocatable_reshape_01
