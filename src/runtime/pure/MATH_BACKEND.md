# Compile-time math backend (`--math-backend`)

| Value | Role |
|-------|------|
| `libm` (default) | Existing path: ASR → `_lfortran_{s,d}{sin,cos}` → host math library |
| `pure` | Opt-in: ASR → `_lfortran_pure_{s,d}{sin,cos}` → Sollya pure Fortran |

Selection is **compile-time** (and link-time for the pure archive). No per-call branch.

## Build / install of pure archive

The main LFortran tree builds pure via `src/runtime/legacy/CMakeLists.txt` (nested with `lfortran_runtime`):

- Finds system `gfortran`
- Compiles `lfortran_intrinsic_trig.f90` + `lfortran_pure_math_abi.f90`
- Writes `liblfortran_runtime_pure_math.a` next to `liblfortran_runtime*` (`build/src/runtime/`)
- `install(FILES ... DESTINATION lib)` for installed layouts

`src/runtime/pure/CMakeLists.txt` remains a standalone harness project.

## Use

```bash
lfortran --math-backend=pure program.f90 -o program
lfortran program.f90 -o program   # default host math library
```

## Layout

- `math_backend.h` — `math_backend_policy()`, `math_c_runtime_symbol()` (shipped helper)
- `lfortran_intrinsic_trig.f90` — Sollya kernels
- `lfortran_pure_math_abi.f90` — `bind(c)` ABI
- `sollya/` — regenerable scripts
