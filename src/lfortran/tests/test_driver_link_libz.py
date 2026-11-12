#!/usr/bin/env python3
"""`-lz` must resolve when the distro multiarch directory has libz.so.

The external clang driver does not search `/usr/lib/<triplet>` on its own.
The link step asks the system C compiler for its default library directories.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile


HELLO = "program hello\nprint *, 'ok'\nend program\n"


def multiarch_libz():
    """libz.so on a directory the system C compiler searches by default."""
    cc = os.environ.get("CC", "cc")
    probed = subprocess.run([cc, "-print-search-dirs"], stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL, universal_newlines=True)
    libraries = ""
    for line in probed.stdout.splitlines():
        if line.startswith("libraries:"):
            libraries = line.split(":", 1)[1].strip()
            break
    if libraries.startswith("="):
        libraries = libraries[1:]
    for directory in libraries.split(":"):
        if directory.startswith("="):
            directory = directory[1:]
        path = os.path.join(directory, "libz.so")
        if directory and os.path.exists(path):
            return path
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lfortran", required=True)
    parser.add_argument("--workdir", required=True)
    args = parser.parse_args()
    libz = multiarch_libz()
    if libz is None:
        print("skipped: no distro multiarch libz.so")
        return
    lfortran = os.path.abspath(args.lfortran)
    os.makedirs(args.workdir, exist_ok=True)
    failures = []
    linkers = [None]
    if shutil.which("clang"):
        linkers.append("clang")
    for linker in linkers:
        with tempfile.TemporaryDirectory(dir=args.workdir) as workdir:
            src = os.path.join(workdir, "hello.f90")
            with open(src, "w") as handle:
                handle.write(HELLO)
            out = os.path.join(workdir, "out.exe")
            cmd = [lfortran, src, "-lz", "-o", out, "--no-color"]
            if linker:
                cmd[1:1] = ["--linker=" + linker]
            result = subprocess.run(cmd, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, universal_newlines=True)
            where = linker or "default linker"
            if result.returncode != 0 or not os.path.isfile(out):
                failures.append("%s did not link %s:\n%s" % (where, libz, result.stdout))
    if failures:
        sys.exit("\n".join(failures))
    print("ok")


if __name__ == "__main__":
    main()
