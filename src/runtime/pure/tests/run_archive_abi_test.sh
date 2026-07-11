#!/usr/bin/env bash
# Build install-shaped pure.a (pure Fortran only) and run production ABI tests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PURE="$ROOT/src/runtime/pure"
WORKDIR="${1:-/tmp/pure-archive-abi-test}"
mkdir -p "$WORKDIR/objs"
FC="${FC:-gfortran}"
$FC -ffree-line-length-none -O3 -fPIC -ftree-vectorize -funroll-loops \
  -J"$WORKDIR/objs" -c "$PURE/lfortran_intrinsic_trig.f90" -o "$WORKDIR/objs/trig.o"
$FC -ffree-line-length-none -O3 -fPIC -ftree-vectorize -funroll-loops \
  -J"$WORKDIR/objs" -I"$WORKDIR/objs" -c "$PURE/lfortran_pure_math_abi.f90" -o "$WORKDIR/objs/abi.o"
ar rcs "$WORKDIR/liblfortran_runtime_pure_math.a" "$WORKDIR/objs/trig.o" "$WORKDIR/objs/abi.o"
$FC -O3 -ffree-line-length-none \
  "$PURE/tests/test_pure_archive_abi.f90" \
  -L"$WORKDIR" -llfortran_runtime_pure_math -o "$WORKDIR/test_pure_archive_abi" -lm
"$WORKDIR/test_pure_archive_abi"
cat > "$WORKDIR/test_specials.f90" << 'F'
program ts
  use iso_c_binding
  implicit none
  interface
    function pure_dsin(x) bind(c, name="_lfortran_pure_dsin") result(r)
      import; real(c_double), value :: x; real(c_double) :: r
    end function
    subroutine pure_dsin_v(n, x, y) bind(c, name="_lfortran_pure_dsin_v")
      import; integer(c_int), value :: n; real(c_double) :: x(n), y(n)
    end subroutine
  end interface
  real(c_double) :: qnan, pinf, r, xv(4), yv(4)
  integer :: i
  qnan = transfer(int(z'7FF8000000000001',8), qnan)
  pinf = transfer(int(z'7FF0000000000000',8), pinf)
  r = pure_dsin(qnan)
  if (r == r) stop 1
  r = pure_dsin(pinf)
  if (r == r) stop 2
  r = pure_dsin(-pinf)
  if (r == r) stop 3
  do i = 1, 4
    xv(i) = 0.25_c_double * real(i, c_double)
  end do
  call pure_dsin_v(4, xv, yv)
  if (abs(yv(1) - pure_dsin(xv(1))) > 1.0e-15_c_double) stop 4
  print *, "PASS specials + pure_dsin_v"
end program
F
$FC -O3 "$WORKDIR/test_specials.f90" -L"$WORKDIR" -llfortran_runtime_pure_math -o "$WORKDIR/ts" -lm
"$WORKDIR/ts"
echo "PASS archive ABI + specials (pure Fortran)"
