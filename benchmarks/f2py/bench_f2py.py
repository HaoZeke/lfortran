#!/usr/bin/env python3
"""f2py extension benchmark: LFortran --fast versus gfortran -O2 and -O3.

NumPy's f2py (the checkout given by NUMPY_SRC) generates the extension. Each
Fortran translation unit is then compiled by the compiler under test and
linked with that compiler's runtime. Meson has no LFortran compiler id, so
this driver does the compile and link f2py's meson backend would do.

Workloads use the SciPy 1.14.1 Fortran sources (fitpack curfit/splev, minpack
lmdif, quadpack dqags, L-BFGS-B setulb, ARPACK dsaupd) plus a triple loop and
a reduction. The timed region is one call into the extension, pinned to CPU 0.

LFortran flags (this is what --fast means in this tree, plus the flags SciPy's
fixed-form sources need and the flag this NumPy adds when FC names LFortran):

  --fast
      optimization passes, bounds checks off, LLVM CodeGen -O3,
      fast-math, and --mcpu=native
  --fast --no-fast-math
      the same, with fast-math off
  --implicit-typing --implicit-interface --legacy-array-sections -fPIC

gfortran:

  -O2 -fPIC -std=legacy
  -O3 -fPIC -std=legacy
  -O3 -march=native -ffast-math -funroll-loops -fPIC -std=legacy
"""

from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import sys
import sysconfig
import textwrap
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")
os.environ.setdefault("NUMEXPR_NUM_THREADS", "1")
os.environ.setdefault("BLIS_NUM_THREADS", "1")

import numpy as np

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
SRC = ROOT / "src"
NUMPY_SRC = Path(os.environ.get("NUMPY_SRC", "/agent/repos/numpy"))
SCIPY_SRC = Path(os.environ.get("SCIPY_SRC", "/tmp/scipy-src/scipy-1.14.1"))
LFORTRAN = Path(os.environ.get(
    "LFORTRAN", str(REPO / "build" / "llvm11" / "src" / "bin" / "lfortran")))
LFORTRAN_RUNTIME = Path(os.environ.get(
    "LFORTRAN_RUNTIME", str(REPO / "build" / "llvm11" / "src" / "runtime")))
GFORTRAN = os.environ.get("GFORTRAN", "gfortran")
GFORTRAN_LIBDIR = str(Path(subprocess.check_output(
    [GFORTRAN, "-print-file-name=libgfortran.so"], text=True).strip()).parent)
OUT = Path(os.environ.get("F2PY_BENCH_OUT", "/tmp/f2py-bench-out"))
PERF = os.environ.get(
    "PERF", "/usr/lib/linux-tools/6.8.0-149-generic/perf")
WARMUP = 3
REPEATS = 25
JOBS = int(os.environ.get("F2PY_BENCH_JOBS", str(os.cpu_count() or 4)))

ARPACK_SRC = (
    "scipy/sparse/linalg/_eigen/arpack/ARPACK/SRC",
    "scipy/sparse/linalg/_eigen/arpack/ARPACK/UTIL",
)


def pin_cpu() -> None:
    try:
        os.sched_setaffinity(0, {0})
    except (AttributeError, OSError) as exc:
        print(f"cpu pin failed: {exc}", file=sys.stderr)


def load_checkout_f2py(numpy_src: Path):
    """Import numpy.f2py from the NumPy checkout, not from the installed copy."""
    f2py_dir = numpy_src / "numpy" / "f2py"
    init = f2py_dir / "__init__.py"
    if not init.is_file():
        raise SystemExit(f"NUMPY_SRC has no f2py: {init}")
    for key in list(sys.modules):
        if key == "numpy.f2py" or key.startswith("numpy.f2py."):
            del sys.modules[key]
    spec = importlib.util.spec_from_file_location(
        "numpy.f2py", init, submodule_search_locations=[str(f2py_dir)])
    module = importlib.util.module_from_spec(spec)
    sys.modules["numpy.f2py"] = module
    spec.loader.exec_module(module)
    return module


def lfortran_flags(f2py_mod, no_fast_math: bool = False) -> list[str]:
    os.environ["FC"] = str(LFORTRAN)
    base = ["--fast", "--implicit-interface", "--legacy-array-sections", "-fPIC"]
    if no_fast_math:
        base.append("--no-fast-math")
    from numpy.f2py._backends._meson import _lfortran_language_flags
    return _lfortran_language_flags(base)


def ensure_scipy(dest: Path) -> Path:
    marker = dest / "scipy" / "interpolate" / "fitpack" / "splev.f"
    if marker.is_file():
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    tarball = dest.parent / "scipy-1.14.1.tar.gz"
    url = "https://github.com/scipy/scipy/archive/refs/tags/v1.14.1.tar.gz"
    print(f"downloading {url}")
    subprocess.run(["curl", "-fsSL", "-o", str(tarball), url], check=True)
    subprocess.run(["tar", "-xzf", str(tarball), "-C", str(dest.parent)], check=True)
    unpacked = dest.parent / "scipy-1.14.1"
    if unpacked.resolve() != dest.resolve() and not marker.is_file():
        raise SystemExit(f"SciPy 1.14.1 sources not found at {dest}")
    return dest if marker.is_file() else unpacked


def fortran_sources(scipy: Path, kind: str) -> list[Path]:
    if kind == "fitpack":
        return sorted((scipy / "scipy/interpolate/fitpack").glob("*.f"))
    if kind == "minpack":
        return sorted((scipy / "scipy/optimize/minpack").glob("*.f"))
    if kind == "quadpack":
        # dqags call closure, plus the machine-constant function it evaluates.
        names = [
            "quadpack/dqags.f", "quadpack/dqagse.f", "quadpack/dqelg.f",
            "quadpack/dqk21.f", "quadpack/dqpsrt.f", "mach/d1mach.f",
            "mach/xerror.f",
        ]
        base = scipy / "scipy/integrate"
        return [base / name for name in names]
    if kind == "lbfgsb":
        return sorted((scipy / "scipy/optimize/lbfgsb_src").glob("*.f"))
    if kind == "arpack":
        # dsaupd/dseupd call closure. The complex drivers need SciPy's g77
        # zdotc wrapper (wzdotc) and are not part of this eigenproblem.
        names = [
            "SRC/dgetv0.f", "SRC/dsaitr.f", "SRC/dsapps.f", "SRC/dsaup2.f",
            "SRC/dsaupd.f", "SRC/dsconv.f", "SRC/dseigt.f", "SRC/dsesrt.f",
            "SRC/dseupd.f", "SRC/dsgets.f", "SRC/dsortr.f", "SRC/dstats.f",
            "SRC/dstqrb.f", "UTIL/dvout.f", "UTIL/ivout.f", "UTIL/second_NONE.f",
        ]
        base = scipy / "scipy/sparse/linalg/_eigen/arpack/ARPACK"
        return [base / name for name in names]
    return []


def run(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


def compile_one(cmd: list[str], log: Path) -> float:
    t0 = time.perf_counter()
    proc = run(cmd)
    elapsed = time.perf_counter() - t0
    log.write_text(proc.stdout)
    if proc.returncode != 0:
        raise RuntimeError(
            f"compile failed ({proc.returncode}): {' '.join(cmd)}\n{proc.stdout[-4000:]}")
    return elapsed


def generate_wrapper(f2py_mod, modname: str, driver: Path, only: list[str], dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    argv = ["-m", modname, str(driver), "only:", *only, ":"]
    previous = os.getcwd()
    os.chdir(dest)
    try:
        saved_out, saved_err = sys.stdout, sys.stderr
        with open(dest / "f2py_gen.log", "w") as log:
            sys.stdout = log
            sys.stderr = log
            try:
                f2py_mod.run_main(argv)
            finally:
                sys.stdout = saved_out
                sys.stderr = saved_err
    finally:
        os.chdir(previous)
    module_c = dest / f"{modname}module.c"
    if not module_c.is_file():
        raise RuntimeError(f"f2py did not write {module_c}")


def c_include_args() -> list[str]:
    args = ["-I", str(np.get_include()), "-I", str(NUMPY_SRC / "numpy" / "f2py" / "src")]
    for key in ("INCLUDEPY", "CONFINCLUDEPY"):
        value = sysconfig.get_config_var(key)
        if value:
            args.extend(["-I", value])
    return args


def build_extension(f2py_mod, spec: dict, compiler: str, flags: list[str],
                    scipy: Path) -> dict:
    modname = f"{spec['name']}_{compiler.replace('-', '_')}"
    dest = OUT / modname
    if dest.exists():
        for child in dest.iterdir():
            if child.is_file():
                child.unlink()
    else:
        dest.mkdir(parents=True)
    generate_wrapper(f2py_mod, modname, spec["driver"], spec["only"], dest)
    objects = []
    fortran_time = 0.0
    sources = [spec["driver"], *fortran_sources(scipy, spec["scipy"])]
    wrappers = list(dest.glob(f"{modname}-f2pywrappers*.f"))
    wrappers += list(dest.glob(f"{modname}-f2pywrappers*.f90"))
    sources.extend(p for p in wrappers if p.stat().st_size > 0)
    inc = []
    if spec["scipy"] == "arpack":
        inc = ["-I", str(scipy / ARPACK_SRC[0])]

    def one(src: Path) -> tuple[Path, float]:
        obj = dest / (src.stem + ".o")
        # Disambiguate duplicate stems (ARPACK has none, but wrappers might).
        if obj.exists():
            obj = dest / (src.parent.name + "_" + src.stem + ".o")
        if compiler.startswith("lfortran"):
            cmd = [str(LFORTRAN), "-c", *flags, *inc, str(src), "-o", str(obj)]
        else:
            cmd = [GFORTRAN, "-c", *flags, *inc, str(src), "-o", str(obj)]
        elapsed = compile_one(cmd, dest / (obj.stem + ".log"))
        return obj, elapsed

    workers = min(JOBS, max(1, len(sources)))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(one, src) for src in sources]
        for fut in as_completed(futures):
            obj, elapsed = fut.result()
            objects.append(obj)
            fortran_time += elapsed

    fortranobject = NUMPY_SRC / "numpy" / "f2py" / "src" / "fortranobject.c"
    module_c = dest / f"{modname}module.c"
    c_flags = ["cc", "-c", "-fPIC", "-O2", *c_include_args()]
    for src in (module_c, fortranobject):
        obj = dest / (src.stem + ".o")
        compile_one([*c_flags, str(src), "-o", str(obj)], dest / (obj.stem + ".clog"))
        objects.append(obj)

    so = dest / f"{modname}.so"
    link = ["cc", "-shared", "-fPIC", "-o", str(so), *[str(o) for o in objects]]
    if compiler.startswith("lfortran"):
        link.extend([
            "-L", str(LFORTRAN_RUNTIME),
            "-Wl,-rpath," + str(LFORTRAN_RUNTIME),
            "-llfortran_runtime",
        ])
    else:
        link.extend(["-L", GFORTRAN_LIBDIR, "-lgfortran"])
    if spec.get("blas"):
        link.extend(["-L", GFORTRAN_LIBDIR, "-lblas", "-llapack", "-lgfortran"])
    link.append("-lm")
    t0 = time.perf_counter()
    proc = run(link)
    link_time = time.perf_counter() - t0
    (dest / "link.log").write_text(proc.stdout)
    if proc.returncode != 0:
        raise RuntimeError(f"link failed: {' '.join(link)}\n{proc.stdout[-4000:]}")
    return {
        "so": str(so),
        "modname": modname,
        "fortran_s": fortran_time,
        "link_s": link_time,
        "compile_s": fortran_time + link_time,
    }


def load_module(modname: str, so: str):
    spec = importlib.util.spec_from_file_location(modname, so)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def summarize(samples: list[float]) -> dict:
    arr = np.asarray(samples, dtype=float)
    q1, med, q3 = np.percentile(arr, [25, 50, 75])
    return {
        "median_s": float(med),
        "iqr_s": float(q3 - q1),
        "min_s": float(arr.min()),
        "max_s": float(arr.max()),
        "samples_s": [float(x) for x in arr],
    }


def time_call(fn) -> dict:
    for _ in range(WARMUP):
        fn()
    samples = []
    for _ in range(REPEATS):
        t0 = time.perf_counter()
        fn()
        samples.append(time.perf_counter() - t0)
    return summarize(samples)


def make_cases(module):
    rng = np.random.default_rng(1)
    n = 500
    a = np.asfortranarray(rng.standard_normal((n, n)))
    b = np.asfortranarray(rng.standard_normal((n, n)))
    ref = a @ b

    def triple():
        return module.bench_triple(a, b)

    def check_triple():
        got = np.asarray(triple(), dtype=float)
        err = np.max(np.abs(got - ref))
        if err > 1e-6 * max(1.0, np.max(np.abs(ref))):
            raise AssertionError(f"triple max abs err {err}")
        return f"max_abs_err={err:.3e}"

    rn = 8_000_000
    nrep = 20
    ra = np.asfortranarray(rng.random(rn))
    rref = nrep * float(np.sum(ra))

    def reduce():
        return float(module.bench_reduce(ra, nrep))

    def check_reduce():
        got = reduce()
        if abs(got - rref) > 1e-5 * abs(rref):
            raise AssertionError(f"reduce got {got} ref {rref}")
        return f"rel_err={abs(got - rref) / abs(rref):.3e}"

    m = 1_000_000
    k = 3
    nest = m + k + 1
    x = np.asfortranarray(np.linspace(0.0, 1.0, m))
    y = np.asfortranarray(np.sin(2.0 * np.pi * x))
    w = np.ones(m, dtype=np.float64, order="F")
    t = np.zeros(nest, dtype=np.float64, order="F")
    c = np.zeros(nest, dtype=np.float64, order="F")
    lwrk = (k + 1) * m + nest * (7 + 3 * k)
    wrk = np.zeros(lwrk, dtype=np.float64, order="F")
    iwrk = np.zeros(nest, dtype=np.int32, order="F")
    spline = {}

    def splrep():
        out = module.bench_splrep(x, y, w, t, c, wrk, iwrk)
        # n, fp, ier are returned; t and c are updated in place.
        if isinstance(out, tuple):
            n_out, fp, ier = out
        else:
            raise AssertionError(f"unexpected splrep return {out!r}")
        spline["n"] = int(n_out)
        spline["fp"] = float(fp)
        spline["ier"] = int(ier)
        spline["t"] = np.array(t[:spline["n"]], dtype=np.float64, order="F", copy=True)
        spline["c"] = np.array(c[:spline["n"]], dtype=np.float64, order="F", copy=True)
        return spline

    def check_splrep():
        got = splrep()
        if got["ier"] > 0:
            raise AssertionError(f"splrep ier={got['ier']} fp={got['fp']}")
        if got["n"] < 2 * k + 2:
            raise AssertionError(f"splrep n={got['n']}")
        return f"ier={got['ier']} n={got['n']} fp={got['fp']:.3e}"

    def splev():
        if "t" not in spline:
            splrep()
        yout, ier = module.bench_splev(spline["t"], spline["c"], k, x)
        return np.asarray(yout), int(ier)

    def check_splev():
        yout, ier = splev()
        err = float(np.max(np.abs(yout - y)))
        if ier != 0 or err > 1e-6:
            raise AssertionError(f"splev ier={ier} max_abs_err={err}")
        return f"ier={ier} max_abs_err={err:.3e}"

    lm = 8000
    x0 = np.array([1.0, 1.0, 1.0, 1.0], dtype=np.float64)

    def lmdif():
        xfit = np.array(x0, copy=True)
        info, nfev, ssq = module.bench_lmdif(lm, xfit)
        return int(info), int(nfev), float(ssq), xfit

    def check_lmdif():
        info, nfev, ssq, xfit = lmdif()
        # info 1..4 are the normal MINPACK stops. -ffast-math can stop at a
        # large residual (info 1) because the predicted reduction collapses.
        if info not in (1, 2, 3, 4):
            raise AssertionError(f"lmdif info={info} nfev={nfev} ssq={ssq} x={xfit}")
        return f"info={info} nfev={nfev} ssq={ssq:.3e}"

    nrep_q = 20000

    def dqags():
        result, abserr, neval, ier = module.bench_dqags(nrep_q)
        return float(result), float(abserr), int(neval), int(ier)

    def check_dqags():
        result, abserr, neval, ier = dqags()
        # nrep integrals of 1/sqrt(x) on (0, 1), each equal to 2.
        err = abs(result / nrep_q - 2.0)
        if ier != 0 or err > 1e-8:
            raise AssertionError(
                f"dqags ier={ier} mean={result / nrep_q} abserr={abserr} neval={neval}")
        return f"ier={ier} err={err:.3e} neval={neval}"

    rn_rb = 1000

    def setulb():
        f, nfg, info = module.bench_setulb(rn_rb)
        return float(f), int(nfg), int(info)

    def check_setulb():
        f, nfg, info = setulb()
        if info != 0 or f > 1e-2:
            raise AssertionError(f"setulb info={info} f={f} nfg={nfg}")
        return f"info={info} f={f:.3e} nfg={nfg}"

    an = 2000
    nev = 10
    ks = np.arange(1, nev + 1)
    lam = 2.0 - 2.0 * np.cos(np.pi * ks / (an + 1))

    def dsaupd():
        evals, info, niter = module.bench_dsaupd(an, nev)
        return np.asarray(evals, dtype=float), int(info), int(niter)

    def check_dsaupd():
        evals, info, niter = dsaupd()
        err = float(np.max(np.abs(np.sort(evals) - lam)))
        if info != 0 or err > 1e-6:
            raise AssertionError(
                f"dsaupd info={info} niter={niter} max_abs_err={err} evals={evals}")
        return f"info={info} niter={niter} max_abs_err={err:.3e}"

    return {
        "triple_loop": (triple, check_triple),
        "reduction": (reduce, check_reduce),
        "fitpack_splrep": (splrep, check_splrep),
        "fitpack_splev": (splev, check_splev),
        "minpack_lmdif": (lmdif, check_lmdif),
        "quadpack_dqags": (dqags, check_dqags),
        "lbfgsb_setulb": (setulb, check_setulb),
        "arpack_dsaupd": (dsaupd, check_dsaupd),
    }


SPECS = [
    {
        "name": "triple_loop",
        "driver": SRC / "triple.f90",
        "only": ["bench_triple"],
        "scipy": "",
        "blas": False,
        "calls": ["triple_loop"],
    },
    {
        "name": "reduction",
        "driver": SRC / "reduce.f90",
        "only": ["bench_reduce"],
        "scipy": "",
        "blas": False,
        "calls": ["reduction"],
    },
    {
        "name": "fitpack",
        "driver": SRC / "fitpack_bench.f90",
        "only": ["bench_splrep", "bench_splev"],
        "scipy": "fitpack",
        "blas": False,
        "calls": ["fitpack_splrep", "fitpack_splev"],
    },
    {
        "name": "minpack",
        "driver": SRC / "minpack_bench.f90",
        "only": ["bench_lmdif"],
        "scipy": "minpack",
        "blas": False,
        "calls": ["minpack_lmdif"],
    },
    {
        "name": "quadpack",
        "driver": SRC / "quadpack_bench.f90",
        "only": ["bench_dqags"],
        "scipy": "quadpack",
        "blas": False,
        "calls": ["quadpack_dqags"],
    },
    {
        "name": "lbfgsb",
        "driver": SRC / "lbfgsb_bench.f90",
        "only": ["bench_setulb"],
        "scipy": "lbfgsb",
        "blas": True,
        "calls": ["lbfgsb_setulb"],
    },
    {
        "name": "arpack",
        "driver": SRC / "arpack_bench.f90",
        "only": ["bench_dsaupd"],
        "scipy": "arpack",
        "blas": True,
        "calls": ["arpack_dsaupd"],
    },
]


def profile_call(so: str, modname: str, call_name: str, fn_source: str) -> dict:
    """Sample the extension with perf cpu-clock and return the top symbols."""
    if not Path(PERF).is_file() and subprocess.run(
            ["bash", "-lc", f"command -v {PERF}"], capture_output=True).returncode != 0:
        return {"error": f"perf not available at {PERF}"}
    runner = OUT / "profile" / f"run_{modname}_{call_name}.py"
    runner.parent.mkdir(parents=True, exist_ok=True)
    runner.write_text(textwrap.dedent(f"""
        import os, sys, time
        os.environ.setdefault("OMP_NUM_THREADS", "1")
        os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
        os.sched_setaffinity(0, {{0}})
        sys.path.insert(0, {str(ROOT)!r})
        # Re-enter the benchmark helpers by exec of the call setup is too heavy.
        # The parent writes a pickled callable? We just import the built module
        # and invoke the same case function reconstructed below.
        import importlib.util
        import numpy as np
        spec = importlib.util.spec_from_file_location({modname!r}, {so!r})
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        sys.path.insert(0, {str(ROOT)!r})
        import bench_f2py
        cases = bench_f2py.make_cases(mod)
        fn, _check = cases[{call_name!r}]
        t_end = time.perf_counter() + 2.5
        n = 0
        while time.perf_counter() < t_end:
            fn()
            n += 1
        print("profile_iters", n)
    """))
    data = OUT / "profile" / f"{modname}_{call_name}.data"
    record = [
        PERF, "record", "-e", "cpu-clock", "-F", "499", "-g",
        "-o", str(data), "--", sys.executable, str(runner),
    ]
    proc = run(record)
    (OUT / "profile" / f"{modname}_{call_name}.record.log").write_text(proc.stdout)
    if proc.returncode != 0:
        return {"error": proc.stdout[-2000:], "record_rc": proc.returncode}
    report = run([
        PERF, "report", "--stdio", "-n", "-i", str(data),
        "--no-children", "--sort", "overhead,dso,symbol",
    ])
    text = report.stdout
    (OUT / "profile" / f"{modname}_{call_name}.report.txt").write_text(text)
    hot = []
    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        if parts[0].endswith("%") and parts[1].isdigit():
            hot.append(line.strip())
        if len(hot) >= 12:
            break
    return {"hot": hot, "source_hint": fn_source}


def main() -> None:
    only = [arg for arg in sys.argv[1:] if not arg.startswith("-")]
    pin_cpu()
    OUT.mkdir(parents=True, exist_ok=True)
    if not LFORTRAN.is_file():
        raise SystemExit(f"LFortran not built: {LFORTRAN}")
    scipy = ensure_scipy(SCIPY_SRC)
    f2py_mod = load_checkout_f2py(NUMPY_SRC)
    lf_flags = lfortran_flags(f2py_mod, no_fast_math=False)
    lf_nofast_flags = lfortran_flags(f2py_mod, no_fast_math=True)
    compilers = [
        ("lfortran", lf_flags),
        ("lfortran-nofast", lf_nofast_flags),
        ("gfortran-O2", ["-O2", "-fPIC", "-std=legacy"]),
        ("gfortran-O3", ["-O3", "-fPIC", "-std=legacy"]),
        ("gfortran-O3-native", [
            "-O3", "-march=native", "-ffast-math", "-funroll-loops",
            "-fPIC", "-std=legacy",
        ]),
    ]
    versions = {
        "lfortran": run([str(LFORTRAN), "--version"]).stdout.splitlines()[:4],
        "gfortran": run([GFORTRAN, "--version"]).stdout.splitlines()[:1],
        "numpy_f2py": str(Path(f2py_mod.__file__).resolve()),
        "numpy_runtime": np.__version__,
        "scipy_src": str(scipy),
        "lfortran_flags": lf_flags,
        "lfortran_nofast_flags": lf_nofast_flags,
        "gfortran_O2": compilers[2][1],
        "gfortran_O3": compilers[3][1],
        "gfortran_O3_native": compilers[4][1],
        "repeats": REPEATS,
        "warmup": WARMUP,
        "cpu": "pinned to logical cpu 0",
    }
    print("flags", lf_flags)
    print("flags-nofast", lf_nofast_flags)
    print("f2py", versions["numpy_f2py"])
    results = {"versions": versions, "workloads": {}}
    built = {}
    selected = [s for s in SPECS if not only or s["name"] in only or any(c in only for c in s["calls"])]
    for spec in selected:
        for compiler, flags in compilers:
            key = f"{spec['name']}:{compiler}"
            print(f"BUILD {key}", flush=True)
            try:
                info = build_extension(f2py_mod, spec, compiler, flags, scipy)
                module = load_module(info["modname"], info["so"])
                cases = make_cases(module)
                info["module"] = module
                info["cases"] = cases
                info["error"] = None
            except Exception as exc:
                info = {"error": str(exc), "compile_s": None, "fortran_s": None}
                print(f"  BUILD FAIL {key}: {exc}", flush=True)
            built[key] = info
            for call in spec["calls"]:
                slot = results["workloads"].setdefault(call, {})
                slot.setdefault("compile", {})[compiler] = {
                    "compile_s": info.get("compile_s"),
                    "fortran_s": info.get("fortran_s"),
                    "link_s": info.get("link_s"),
                    "error": info.get("error"),
                }

    for spec in selected:
        for call in spec["calls"]:
            for compiler, _flags in compilers:
                info = built[f"{spec['name']}:{compiler}"]
                slot = results["workloads"][call].setdefault(compiler, {})
                if info.get("error"):
                    slot["error"] = info["error"]
                    print(f"SKIP {call} {compiler}", flush=True)
                    continue
                fn, check = info["cases"][call]
                print(f"RUN {call} {compiler}", flush=True)
                try:
                    note = check()
                    stats = time_call(fn)
                    slot.update(stats)
                    slot["check"] = note
                    slot["error"] = None
                    print(f"  median {stats['median_s']:.6f}s  iqr {stats['iqr_s']:.6f}s  {note}",
                          flush=True)
                except Exception as exc:
                    slot["error"] = str(exc)
                    print(f"  RUN FAIL {call} {compiler}: {exc}", flush=True)

    # Ratios. Profile when --fast is >1.5x the matched native fast-math gfortran.
    profiles = {}
    ratio_pairs = (
        ("lfortran", "gfortran-O2", "ratio_lfortran_over_O2"),
        ("lfortran", "gfortran-O3", "ratio_lfortran_over_O3"),
        ("lfortran", "gfortran-O3-native", "ratio_lfortran_over_O3_native"),
        ("lfortran-nofast", "gfortran-O3", "ratio_nofast_over_O3"),
        ("lfortran-nofast", "gfortran-O3-native", "ratio_nofast_over_O3_native"),
    )
    for call, slot in results["workloads"].items():
        for left, right, key in ratio_pairs:
            a = slot.get(left, {})
            b = slot.get(right, {})
            if a.get("median_s") and b.get("median_s"):
                slot[key] = a["median_s"] / b["median_s"]
        native = slot.get("ratio_lfortran_over_O3_native")
        if native is not None and native > 1.5:
            print(f"PROFILE {call} ratio_vs_O3_native {native:.2f}", flush=True)
            spec = next(s for s in SPECS if call in s["calls"])
            info = built[f"{spec['name']}:lfortran"]
            profiles[call] = profile_call(info["so"], info["modname"], call, spec["driver"].name)
            slot["profile"] = profiles[call]

    serializable = json.loads(json.dumps(results, default=str))
    (OUT / "results.json").write_text(json.dumps(serializable, indent=2))
    print(json.dumps({
        "out": str(OUT / "results.json"),
        "ratios": {
            call: {
                "lf_over_O2": slot.get("ratio_lfortran_over_O2"),
                "lf_over_O3": slot.get("ratio_lfortran_over_O3"),
                "lf_over_O3_native": slot.get("ratio_lfortran_over_O3_native"),
                "nofast_over_O3": slot.get("ratio_nofast_over_O3"),
                "nofast_over_O3_native": slot.get("ratio_nofast_over_O3_native"),
            }
            for call, slot in results["workloads"].items()
        },
    }, indent=2))


if __name__ == "__main__":
    main()
