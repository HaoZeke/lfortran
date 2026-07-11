# Compile-time math backend (`--math-backend`)

| Value | Role |
|-------|------|
| `libm` (default) | ASR → `_lfortran_{s,d}{sin,cos}` → host math library |
| `pure` | Opt-in: scalar → `_lfortran_pure_{s,d}{sin,cos}`; whole-array kind-8 `y=sin(x)`/`y=cos(x)` → `_lfortran_pure_d{sin,cos}_v` |

Selection is **compile-time** (and link-time for the pure archive). No per-call branch.

## Build / install of pure archive

The main LFortran tree builds pure via `src/runtime/legacy/CMakeLists.txt`:

- Uses system **gfortran** so the C/C++ LFortran tree can ship the archive without a circular dependency on the LFortran Fortran frontend (packaging only; kernels are pure Fortran + Sollya, not C).
- Compiles `lfortran_intrinsic_trig.f90` + `lfortran_pure_math_abi.f90` with **`-O3 -fPIC`** (no LTO IR; LFortran links with clang/g++ without `-flto`).
- Writes `liblfortran_runtime_pure_math.a` next to `liblfortran_runtime*`.

## Array pure

Without bulk wiring, array pure is N scalar external `_lfortran_pure_dsin` calls (slow vs host vector math). Under pure, `array_op` lowers whole-array kind-8 `y = sin(x)` / `y = cos(x)` (addressable `Var` bases, no sections) to one bulk call. Sections, kind-4, and nested expressions fall back to elemental scalar pure.

## IEEE specials

NaN and ±Inf use F2003/F2008 **`ieee_arithmetic`** (`ieee_is_nan`, `ieee_is_finite`, `ieee_value(..., ieee_quiet_nan)`). **`iso_fortran_env` does not provide NaN/Inf predicates.**

## Use

```bash
lfortran --math-backend=pure program.f90 -o program
lfortran program.f90 -o program   # default host math library
```

## Layout

- `math_backend.h` — scalar + bulk symbol helpers
- `lfortran_intrinsic_trig.f90` — Sollya elemental kernels
- `lfortran_pure_math_abi.f90` — bind(C) production ABI (scalar + bulk)
- `sollya/` — regenerable scripts
