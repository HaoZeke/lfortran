      program fixed_form_flag_01
      integer x
      call mwe(
     & x)
      if (x .ne. 7) stop 1
      end
      subroutine mwe(x)
      integer x
      x = 7
      end
