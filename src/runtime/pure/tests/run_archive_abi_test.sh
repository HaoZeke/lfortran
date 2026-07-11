#!/usr/bin/env bash
# Build install-shaped pure.a (no LTO) and run production ABI accuracy test.
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
$FC -O3 -ffree-line-length-none -I"$WORKDIR/objs" \
  "$PURE/tests/test_pure_archive_abi.f90" \
  -L"$WORKDIR" -llfortran_runtime_pure_math -o "$WORKDIR/test_pure_archive_abi" -lm
"$WORKDIR/test_pure_archive_abi"
echo "PASS archive ABI test (lib=$WORKDIR/liblfortran_runtime_pure_math.a)"
