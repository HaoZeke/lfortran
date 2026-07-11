#!/usr/bin/env python

import os
import shutil
import subprocess
from pathlib import Path

import click
import tomli
from jinja2 import Environment, FileSystemLoader


@click.command()
@click.option("--compiler", default="gfortran", help="The compiler used")
@click.option("--execute/--no-execute", default=False)
@click.option("--plot/--no-plot", default=False)
@click.option("--build/--no-build", default=False)
@click.option("--genfiles", is_flag=True)
def mkfunc(compiler, genfiles, execute, plot, build):
    """Generate pure-runtime abs-error grids (gfortran vs pure module)."""
    template_loader = FileSystemLoader("./")
    env = Environment(loader=template_loader)
    buildtemplate = env.get_template("cmake.jinja")
    tests_dict = tomli.loads(Path("gen.toml").read_bytes().decode())
    execenv = os.environ.copy()
    execenv["FC"] = compiler
    for mod, ftests in tests_dict.items():
        testtemplate = env.get_template(f"{mod}.f90.jinja")
        lfmn = f"lfortran_intrinsic_{mod}.f90"
        lfmod = Path(Path.cwd().parent / lfmn).absolute()
        moddirname = Path(Path.cwd() / f"gentests/{mod}").absolute()
        Path.mkdir(moddirname, parents=True, exist_ok=True)
        for func in ftests:
            funcdirname = moddirname / func["fname"]
            Path.mkdir(funcdirname, exist_ok=True)
            shutil.copy(lfmod, funcdirname)
            fn = f"{func['fname']}_test.f90"
            test_data = {
                "test_name": f"{func['fname']}_test",
                "test_files": [lfmn, fn],
            }
            func = dict(func)
            func["compiler"] = compiler
            Path.write_text(funcdirname / fn, testtemplate.render(func))
            Path.write_text(
                funcdirname / "CMakeLists.txt", buildtemplate.render(test_data)
            )
            subprocess.Popen(["cmake", "."], env=execenv, cwd=funcdirname).wait()
            if build:
                subprocess.Popen(
                    ["cmake", "--build", "."], env=execenv, cwd=funcdirname
                ).wait()
                if execute:
                    out = funcdirname / f"{compiler}_{func['fname']}_output.dat"
                    with open(out, "w") as res:
                        subprocess.Popen(
                            [f"./{test_data['test_name']}"],
                            env=execenv,
                            cwd=funcdirname,
                            stdout=res,
                        ).wait()
                    summarize(out)
                if plot:
                    mkplot(
                        funcdirname / f"{compiler}_{func['fname']}_output.dat"
                    )


def summarize(pathname):
    """Print max/mean abs_error from a harness .dat file."""
    path = Path(pathname)
    xs, errs = [], []
    with path.open() as f:
        for line in f:
            parts = line.split()
            if len(parts) < 4:
                continue
            try:
                x = float(parts[0])
                e = float(parts[3])
            except ValueError:
                continue
            xs.append(x)
            errs.append(e)
    if not errs:
        print(f"{path}: no data rows")
        return
    mx = max(errs)
    mean = sum(errs) / len(errs)
    imax = errs.index(mx)
    print(
        f"{path.name}: n={len(errs)} max_abs_err={mx:.6e} "
        f"at x={xs[imax]:.6g} mean_abs_err={mean:.6e}"
    )


def mkplot(pathname):
    """Abs-error vs argument (optional; needs matplotlib)."""
    path = Path(pathname)
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print(f"mkplot: matplotlib missing, skip {path}")
        return
    xs, errs = [], []
    with path.open() as f:
        for line in f:
            parts = line.split()
            if len(parts) < 4:
                continue
            try:
                xs.append(float(parts[0]))
                errs.append(float(parts[3]))
            except ValueError:
                continue
    if not xs:
        return
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.semilogy(xs, [e if e > 0 else 1e-300 for e in errs], lw=0.6)
    ax.set_xlabel("x")
    ax.set_ylabel("|gfortran - pure|")
    ax.set_title(path.name)
    ax.grid(True, which="both", alpha=0.3)
    out = path.with_suffix(".png")
    fig.tight_layout()
    fig.savefig(out, dpi=120)
    plt.close(fig)
    print(f"wrote {out}")


if __name__ == "__main__":
    mkfunc()
