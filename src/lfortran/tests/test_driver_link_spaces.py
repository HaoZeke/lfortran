#!/usr/bin/env python3
"""The link step must keep a space inside one argument.

`-o` and `-Wl` paths used to be pasted into a shell string, so the space
became a second filename (`clang: error: no such file or directory: 'with'`).
"""

import argparse
import os
import subprocess
import sys
import tempfile


HELLO = "program hello\nprint *, 'ok'\nend program\n"


def run(cmd, cwd):
    return subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, universal_newlines=True)


def check(lfortran, workdir, linker):
    spaced = os.path.join(workdir, "dir with space")
    os.makedirs(spaced, exist_ok=True)
    src = os.path.join(workdir, "hello.f90")
    with open(src, "w") as handle:
        handle.write(HELLO)
    out = os.path.join(spaced, "out.exe")
    rpath = os.path.join(spaced, "libs")
    os.makedirs(rpath, exist_ok=True)
    cmd = [lfortran, src, "-o", out, "-Wl,-rpath," + rpath, "--no-color"]
    if linker:
        cmd[1:1] = ["--linker=" + linker]
    result = run(cmd, workdir)
    failures = []
    if result.returncode != 0 or not os.path.isfile(out):
        failures.append("link failed:\n" + result.stdout)
    else:
        ran = run([out], workdir)
        if ran.returncode != 0 or "ok" not in ran.stdout:
            failures.append("program failed:\n" + ran.stdout + result.stdout)
    if failures:
        where = linker or "default linker"
        return ["%s: %s" % (where, " ".join(failures))]
    return []


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lfortran", required=True)
    parser.add_argument("--workdir", required=True)
    args = parser.parse_args()
    lfortran = os.path.abspath(args.lfortran)
    os.makedirs(args.workdir, exist_ok=True)
    failures = []
    for linker in (None, "gcc", "clang"):
        with tempfile.TemporaryDirectory(dir=args.workdir) as workdir:
            failures += check(lfortran, workdir, linker)
    if failures:
        sys.exit("\n".join(failures))
    print("ok")


if __name__ == "__main__":
    main()
