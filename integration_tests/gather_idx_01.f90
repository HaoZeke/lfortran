! wy(ind(i), j) is a gather. The address is sext(ind(i)) plus a
! column offset. --fast must keep that address, including when the
! loaded index stays 32-bit so the gather is vgatherdpd.
module gather_idx_01_mod
implicit none
contains
subroutine accum(n, m, ind, wy, ws, wv, d)
integer, intent(in) :: n, m, ind(n)
double precision, intent(in) :: wy(n, m), ws(n, m), wv(m)
double precision, intent(inout) :: d(n)
integer :: j, i, k
do j = 1, m
    do i = 1, n
        k = ind(i)
        d(i) = d(i) + wy(k, j) * wv(j) + ws(k, j)
    end do
end do
end subroutine accum
end module gather_idx_01_mod

program gather_idx_01
use gather_idx_01_mod
implicit none
integer, parameter :: n = 4, m = 2
integer :: ind(n), i, j
double precision :: wy(n, m), ws(n, m), wv(m), d(n)
procedure(accum), pointer :: update
ind = [2, 4, 1, 3]
do j = 1, m
    wv(j) = j
    do i = 1, n
        wy(i, j) = i + 10.0d0 * j
        ws(i, j) = i - j
    end do
end do
d = 0.0d0
update => accum
call update(n, m, ind, wy, ws, wv, d)
if (d(1) /= 57.0d0) error stop
if (d(2) /= 67.0d0) error stop
if (d(3) /= 52.0d0) error stop
if (d(4) /= 62.0d0) error stop
end program
