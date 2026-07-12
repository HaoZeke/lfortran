# Pure math backend tests

| Script / file | What it checks |
|---------------|----------------|
| `check_math_backend_wiring.py` | Source wiring (CLI, symbols, CMake pure.a, bulk hooks) |
| `run_archive_abi_test.sh` | Build pure.a (no LTO) + scalar and bulk ABI smoke |
| `test_pure_bulk_abi.f90` | Drives `_lfortran_pure_d{sin,cos}_v` from the archive |
| `test_pure_array_e2e.f90` | Compile with `lfortran --math-backend=pure` |
| `test_pure_accuracy_r128.f90` | pure ABI vs `real128` on [-20,20] |
| `metrics/run_metrics.py` | Fair pure vs host timing (no LTO) |

See `../MATH_BACKEND.md` for design.
