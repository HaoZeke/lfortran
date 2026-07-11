#!/usr/bin/env python3
"""Assert compile-time math-backend wiring exists in the tree (default libm, pure opt-in)."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[4]  # repo root from pure/tests
if not (root / "src/libasr/utils.h").is_file():
    root = Path(__file__).resolve().parents[3]
    # try: pure/tests -> pure -> runtime -> src -> root is parents[3]
    if not (root / "src/libasr/utils.h").is_file():
        # parents: tests=0 pure=1 runtime=2 src=3 repo=4
        root = Path(__file__).resolve().parents[4]

checks = [
    (root / "src/libasr/utils.h", r'math_backend\s*=\s*"libm"', "PassOptions default libm"),
    (root / "src/libasr/utils.h", r"math_backend.h", "utils includes math_backend"),
    (root / "src/libasr/math_backend.h", r"_lfortran_pure_d", "pure d-symbol naming"),
    (root / "src/libasr/math_backend.h", r"math_c_runtime_symbol", "symbol helper header"),
    (root / "src/runtime/legacy/CMakeLists.txt", r"lfortran_runtime_pure_math", "legacy builds pure_math archive"),
    (root / "src/libasr/pass/intrinsic_functions.h", r"math_c_runtime_symbol", "instantiate uses helper"),
    (root / "src/libasr/pass/intrinsic_function.cpp", r"math_backend_policy\(\)\s*=\s*pass_options\.math_backend", "pass sets policy"),
    (root / "src/bin/lfortran_command_line_parser.cpp", r"--math-backend", "CLI flag"),
    (root / "src/bin/lfortran.cpp", r"lfortran_runtime_pure_math", "link pure math lib"),
    (root / "src/runtime/pure/lfortran_pure_math_abi.f90", r"_lfortran_pure_dsin", "pure ABI export"),
    (root / "src/runtime/pure/lfortran_pure_math_abi.f90", r"_lfortran_pure_dcos", "pure cos ABI export"),
    # Elemental dsin/dcos are the sin/cos intrinsic bodies (fully inlined Horner)
    (root / "src/runtime/pure/lfortran_intrinsic_trig.f90", r"elemental pure function dsin", "pure sin elemental"),
    (root / "src/runtime/pure/lfortran_intrinsic_trig.f90", r"elemental pure function dcos", "pure cos elemental"),
    (root / "src/runtime/pure/lfortran_intrinsic_trig.f90", r"inv_pi", "pure range reduction"),
]

failed = []
for path, pat, label in checks:
    if not path.is_file():
        failed.append(f"MISSING FILE {path} ({label})")
        continue
    text = path.read_text(errors="replace")
    if not re.search(pat, text):
        failed.append(f"FAIL {label}: /{pat}/ not in {path.relative_to(root)}")
    else:
        print(f"OK {label}")

# Default path must still name classic host-math symbols when backend is libm
mb = (root / "src/libasr/math_backend.h").read_text()
if '_lfortran_d' not in mb or 'backend == "libm"' not in mb and '"libm"' not in mb:
    # accept pure/libm branches present
    if '_lfortran_s' not in mb or '_lfortran_d' not in mb:
        failed.append("FAIL default host-math d-symbol naming missing from math_backend.h")
    else:
        print("OK default host-math naming present")
else:
    print("OK default host-math naming present")

if failed:
    print("\n".join(failed), file=sys.stderr)
    sys.exit(1)
print("PASS check_math_backend_wiring")
