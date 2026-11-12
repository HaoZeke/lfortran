#!/usr/bin/env python3
"""`--openmp` defines `_OPENMP` for `--cpp` and links the OpenMP runtime.

The lowering emits GOMP_* calls. Those resolve in libgomp, or in libomp
when libgomp is not installed.
"""

import argparse
import os
import subprocess
import sys
import tempfile


MACRO = "program p\nprint *, _OPENMP\nend program\n"
PARALLEL = """\
program p
use omp_lib
implicit none
integer :: n
n = omp_get_num_threads()
if (n < 1) error stop 1
print *, "ok"
end program
"""


def run(cmd):
    return subprocess.run(cmd, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, universal_newlines=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lfortran", required=True)
    parser.add_argument("--workdir", required=True)
    args = parser.parse_args()
    lfortran = os.path.abspath(args.lfortran)
    os.makedirs(args.workdir, exist_ok=True)
    failures = []
    with tempfile.TemporaryDirectory(dir=args.workdir) as workdir:
        src = os.path.join(workdir, "macro.f90")
        with open(src, "w") as handle:
            handle.write(MACRO)
        plain = run([lfortran, "--cpp", "-E", src, "--no-color"])
        if plain.returncode != 0 or "_OPENMP" not in plain.stdout:
            failures.append("without --openmp, _OPENMP was rewritten:\n" + plain.stdout)
        defined = run([lfortran, "--openmp", "--cpp", "-E", src, "--no-color"])
        if defined.returncode != 0 or "201511" not in defined.stdout:
            failures.append("--openmp --cpp did not define _OPENMP as 201511:\n"
                + defined.stdout)
        if "_OPENMP" in defined.stdout:
            failures.append("the _OPENMP token survived preprocessing:\n" + defined.stdout)

        src = os.path.join(workdir, "parallel.f90")
        with open(src, "w") as handle:
            handle.write(PARALLEL)
        obj = os.path.join(workdir, "parallel.o")
        compiled = run([lfortran, "--openmp", "-c", src, "-o", obj, "--no-color"])
        if compiled.returncode != 0 or not os.path.isfile(obj):
            failures.append("--openmp did not compile the call:\n" + compiled.stdout)
        else:
            # The link line does not repeat --openmp. The object references
            # omp_get_num_threads, so the driver must add the runtime.
            out = os.path.join(workdir, "parallel.exe")
            linked = run([lfortran, obj, "-o", out, "--no-color"])
            if linked.returncode != 0 or not os.path.isfile(out):
                failures.append("the OpenMP runtime was not linked:\n" + linked.stdout)
            else:
                ran = run([out])
                if ran.returncode != 0 or "ok" not in ran.stdout:
                    failures.append("OpenMP program failed:\n" + ran.stdout)
    if failures:
        sys.exit("\n".join(failures))
    print("ok")


if __name__ == "__main__":
    main()
