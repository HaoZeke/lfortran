#!/usr/bin/env bash
# Build install-shaped pure.a (pure Fortran only, no LTO) and run production ABI tests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
PURE="$ROOT/src/runtime/pure"
WORKDIR="${1:-/tmp/pure-archive-abi-test}"
mkdir -p "$WORKDIR/objs"
FC="${FC:-gfortran}"
# Match production pure.a flags (host-tune, no LTO)
FFLAGS=(-ffree-line-length-none -O3 -fPIC -ftree-vectorize -funroll-loops
        -ffp-contract=fast -fno-math-errno -march=native)

"$FC" "${FFLAGS[@]}" -J"$WORKDIR/objs" -c "$PURE/lfortran_intrinsic_trig.f90" \
  -o "$WORKDIR/objs/trig.o"
"$FC" "${FFLAGS[@]}" -J"$WORKDIR/objs" -I"$WORKDIR/objs" -c "$PURE/lfortran_pure_math_abi.f90" \
  -o "$WORKDIR/objs/abi.o"
ar rcs "$WORKDIR/liblfortran_runtime_pure_math.a" \
  "$WORKDIR/objs/trig.o" "$WORKDIR/objs/abi.o"

"$FC" -O3 -ffree-line-length-none -march=native \
  "$PURE/tests/test_pure_archive_abi.f90" \
  -L"$WORKDIR" -llfortran_runtime_pure_math -o "$WORKDIR/test_pure_archive_abi" -lm
"$WORKDIR/test_pure_archive_abi"

"$FC" -O3 -ffree-line-length-none -march=native \
  "$PURE/tests/test_pure_bulk_abi.f90" \
  -L"$WORKDIR" -llfortran_runtime_pure_math -o "$WORKDIR/test_pure_bulk_abi" -lm
"$WORKDIR/test_pure_bulk_abi"

echo "PASS archive ABI + bulk (pure Fortran, no LTO)"
