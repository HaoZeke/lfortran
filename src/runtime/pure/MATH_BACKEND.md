# Math backend: `--math-backend=libm|pure`

## What this is

LFortran can lower real `sin` / `cos` in two ways:

| Backend | Default? | What happens |
|---------|----------|----------------|
| `libm` | **yes** | Same as today: ASR → `_lfortran_{s,d}{sin,cos}` → host math library |
| `pure` | opt-in | ASR → owned Sollya kernels in pure Fortran (`liblfortran_runtime_pure_math.a`) |

There is **no per-call switch**. The backend is fixed at compile time (and pure programs also link the pure archive).

Complex `sin`/`cos` always use the host path, even with `--math-backend=pure`.

## Why pure exists

- Polynomials come from Sollya scripts under `sollya/` (regenerable, not hand-tuned magic constants alone).
- Implementation is **pure Fortran** (no C kernels in the pure archive).
- Useful when you want owned elementary kernels for research, testing, or avoiding host libm differences—not as a drop-in replacement for libmvec on every machine.

## How users enable it

```bash
# default: host math
lfortran program.f90 -o program

# opt-in pure sin/cos
lfortran --math-backend=pure program.f90 -o program
```

Requires that the build produced `liblfortran_runtime_pure_math.a` (needs system `gfortran` at configure time).

## What pure emits

| User code | Symbol under pure |
|-----------|-------------------|
| scalar `s = sin(x)` / `cos(x)` (real64) | `_lfortran_pure_dsin` / `_lfortran_pure_dcos` |
| whole-array `y = sin(x)` / `cos(x)` (real64, contiguous vars) | `_lfortran_pure_dsin_v` / `_lfortran_pure_dcos_v` (one bulk call) |
| real32 | `_lfortran_pure_s{sin,cos}` (scalar path) |
| array sections, kind-4 arrays, expressions like `sin(2*x)` | scalar pure calls per element (not bulk) |

Without the bulk wiring, array pure would be N scalar external calls. Bulk is only for the common whole-array kind-8 case.

## Packaging: why gfortran builds pure.a

The LFortran tree is C/C++. Building the pure Fortran runtime with **system gfortran** avoids a circular dependency on the LFortran frontend.

- Objects are ordinary `-O3` code (host-tuned with `-march=native` for SIMD on the build machine).
- **No LTO IR** in the archive, so the usual clang/g++ LFortran driver can link it without `-flto`.

## Layout

| Path | Role |
|------|------|
| `sollya/sin_odd.sollya`, `cos_even.sollya` | Coefficient generation |
| `lfortran_intrinsic_trig.f90` | Elemental Sollya kernels (module) |
| `lfortran_pure_math_abi.f90` | Production `bind(C)` scalar + bulk ABI |
| `lfortran_pure_math.h` | C declarations for tests |
| `tests/` | Wiring check, archive/bulk smoke, metrics harness |
| `../../libasr/math_backend.h` | Symbol naming helper used by intrinsic instantiation |

## Tests (re-runnable)

```bash
python3 src/runtime/pure/tests/check_math_backend_wiring.py
bash src/runtime/pure/tests/run_archive_abi_test.sh /tmp/pure-archive-abi
cd src/runtime/pure/tests/metrics && python3 run_metrics.py --out-dir /tmp/pure-metrics --skip-lfortran
# with a pure-capable lfortran on PATH:
lfortran --math-backend=pure -O3 -o t src/runtime/pure/tests/test_pure_array_e2e.f90 && ./t
```

## Limits (honest)

- Scope today: real `sin`/`cos` only.
- Bulk is not libmvec; on a typical x86_64 host, bulk pure can be a few times slower than host array `sin` while still far faster than N scalar pure calls.
- Scalar pure is competitive with external C `sin` (often faster under fair ABI-to-ABI timing).
