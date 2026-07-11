# Compile-time math backend (`--math-backend`)

| Value | Role |
|-------|------|
| `libm` (default) | Existing path: ASR → `_lfortran_{s,d}{sin,cos}` → host libm |
| `pure` | Opt-in: ASR → `_lfortran_pure_{s,d}{sin,cos}` → Sollya pure Fortran kernels |

Selection is **compile-time** (and link-time for the pure archive). There is no per-call branch inside `sin`/`cos`.

## Use

```bash
lfortran --math-backend=pure program.f90 -o program
lfortran program.f90 -o program   # default libm
```

Pure currently implements **real** `sin` and `cos` only. Other elementals stay on libm names under `--math-backend=pure`.

## Layout

- `lfortran_intrinsic_trig.f90` — Sollya kernels
- `lfortran_pure_math_abi.f90` — `bind(c)` ABI for the compiler
- `sollya/` — regenerable coefficient scripts
- `tests/` — harness, kernel_check, wiring check, demos

## Value

Owned elementary kernels: regenerable from Sollya, dogfoodable pure Fortran, bit-stable across hosts that share the same pure object code (unlike host libm differences). Accuracy on the stated domain is ~1e-15 vs gfortran/libm on the historical grid; not a last-bit SVML replacement.
