C     A function name that contains digits followed by H is an identifier.
C     The 2H in MA02HD is not an nH edit descriptor.
      logical function ma02hd(n)
      integer n
      if (n .eq. 0) then
         ma02hd = .false.
      else
         ma02hd = .true.
      end if
      end

      program function_name_hollerith_01
      logical ma02hd
      external ma02hd
      if (ma02hd(1)) then
         print *, 'ok'
      else
         print *, 'bad'
      end if
      end
