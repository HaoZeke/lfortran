C     nH edit descriptors keep blanks, and a count that runs through
C     the column-72 pad onto the continuation line.
      program hollerith_fixed_form_01
      write(*,10)
   10 format(46HSEQUENTIAL LEAST SQUARES PROGRAMMING ALGORITHM)
      write(*,20)
   20 format(                                           13HOPTIMIZATION
     1)
      write(*,30)
   30 format(                                                       11H
     1ITERATIONS)
      end
