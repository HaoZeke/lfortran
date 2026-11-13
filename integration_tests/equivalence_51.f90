! A SAVE variable equivalenced with an array keeps that array alive
! across calls. The array is the storage; the saved alias must not
! point at a temporary that disappears when the function returns.
program equivalence_51
implicit none
double precision :: first, second
first = overlay(1)
second = overlay(2)
print *, first
print *, second
if (first /= 1.0d0) error stop 1
if (second /= 2.0d0) error stop 2

contains

    double precision function overlay(k)
        integer, intent(in) :: k
        integer :: lo(2), hi(2), ready
        double precision :: block(2)
        save lo, hi, ready
        equivalence (block(1), lo(1))
        equivalence (block(2), hi(1))
        if (ready /= 1) then
            block(1) = 1.0d0
            block(2) = 2.0d0
            ready = 1
        end if
        overlay = block(k)
    end function overlay

end program equivalence_51
