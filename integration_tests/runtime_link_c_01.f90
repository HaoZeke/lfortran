program runtime_link_c_01
    implicit none
    interface
        integer function c_side() bind(c)
        end function c_side
    end interface
    if (c_side() /= 4) error stop 1
end program runtime_link_c_01
