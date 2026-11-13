C A .f file is fixed form, and its DO variable is implicit.
      PROGRAM LEGACY_FIXED_FORM_01
      REAL*8 A(4)
      DO I = 1, 4
         A(I) = I
      ENDDO
      IF (A(4) .NE. 4.0D0) STOP 1
      END
