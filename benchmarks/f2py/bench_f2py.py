#!/usr/bin/env python3
"""f2py extension benchmark: LFortran --fast versus gfortran -O2 and -O3.

NumPy's f2py (the checkout given by NUMPY_SRC) generates the extension. Each
Fortran translation unit is then compiled by the compiler under test and
linked with that compiler's runtime. Meson has no LFortran compiler id, so
this driver does the compile and link f2py's meson backend would do.

Workloads use the SciPy 1.14.1 Fortran sources (fitpack curfit/splev, minpack
lmdif and hybrd1, quadpack dqags, L-BFGS-B setulb, ARPACK dsaupd, ODEPACK
lsoda, ODRPACK dodr, the deterministic iddr_id closure, PROPACK dlansvd)
plus FFTPACK 4 rfftf/rfftb (the real transforms SciPy 1.3.3 shipped;
1.14.1 no longer has them), a triple loop, and a reduction. specfun in
1.14.1 is the C++ port under scipy/special/special/specfun, so it is not
a Fortran workload here. The timed region is one call into the extension.
Compilers share one core: each repeat runs every compiler once, in
rotating order, after a warmup of the same shape.

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
  -O3 -march=native -fPIC -std=legacy
  -O3 -march=native -ffast-math -funroll-loops -fPIC -std=legacy

Only the last of those, and LFortran --fast, turn fast math on.
benchmarks/f2py/README.md names the ratio columns.
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
    if kind == "odepack":
        names = [
            "blkdta000.f", "bnorm.f", "cfode.f", "ewset.f", "fnorm.f",
            "intdy.f", "lsoda.f", "prja.f", "solsy.f", "srcma.f", "stoda.f",
            "vmnorm.f", "xerrwv.f", "xsetf.f", "xsetun.f",
        ]
        base = scipy / "scipy/integrate/odepack"
        sources = [base / name for name in names]
        sources.append(scipy / "scipy/integrate/mach/d1mach.f")
        return sources
    if kind == "fftpack":
        # Real rffti/rfftf/rfftb and the radf/radb kernels in the same files.
        return sorted((SRC / "fftpack").glob("*.f"))
    if kind == "odrpack":
        names = ["d_odr.f", "d_lpk.f", "d_mprec.f", "dlunoc.f"]
        base = scipy / "scipy/odr/odrpack"
        return [base / name for name in names]
    if kind == "id_dist":
        # The full SciPy closure, including the SVD and FFTPACK sources.
        # Those pass a real or complex workspace to an integer or real dummy.
        base = scipy / "scipy/linalg/src/id_dist/src"
        return sorted(base.glob("*.f"))
    if kind == "propack":
        names = [
            "dblasext.F", "dlansvd.F", "dlanbpro.F", "dreorth.F",
            "dgetu0.F", "dsafescal.F", "dritzvec.F", "dmgs.risc.F",
            "dbsvd.F", "dgemm_ovwr.F", "printstat.F",
        ]
        base = scipy / "scipy/sparse/linalg/_propack/PROPACK/double"
        return [base / name for name in names]
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
    for rel in spec.get("include", []):
        inc.extend(["-I", str(scipy / rel)])
    if spec["scipy"] == "arpack":
        inc.extend(["-I", str(scipy / ARPACK_SRC[0])])

    def one(src: Path) -> tuple[Path, float]:
        obj = dest / (src.stem + ".o")
        # Disambiguate duplicate stems (ARPACK has none, but wrappers might).
        if obj.exists():
            obj = dest / (src.parent.name + "_" + src.stem + ".o")
        extra = []
        # gfortran preprocesses .F from the suffix. LFortran needs both
        # the preprocessor and fixed form for those SciPy sources.
        if src.suffix == ".F" and compiler.startswith("lfortran"):
            extra.extend(["--fixed-form", "--cpp"])
        # id_dist stores integer factor tables in a real or complex
        # workspace. --implicit-argument-casting passes those bytes
        # through, which is what --std=legacy does.
        if spec.get("cast") and compiler.startswith("lfortran"):
            extra.append("--implicit-argument-casting")
        if compiler.startswith("lfortran"):
            cmd = [str(LFORTRAN), "-c", *flags, *extra, *inc, str(src), "-o", str(obj)]
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


# First match wins. Longer names are listed before `n` so `nfev=` is not read as `n=`.
_WORK_KEYS = ("nfev", "neval", "nfg", "niter", "nfe", "nst", "n")


def _note_work(note: str) -> tuple[str, int] | None:
    """Pull a work count out of a check note. 0 means the call did no work."""
    found: dict[str, int] = {}
    for part in note.replace(",", " ").split():
        key, sep, val = part.partition("=")
        if sep != "=" or key not in _WORK_KEYS:
            continue
        try:
            found[key] = int(val)
        except ValueError:
            continue
    for key in _WORK_KEYS:
        count = found.get(key)
        if count:
            return key, count
    return None


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
        # s = 0 asks for the interpolating spline: ier -1, fp 0, and one
        # knot past every sample. ier 0 with a short knot set is a different,
        # cheaper path and must not pass.
        if got["ier"] != -1 or got["n"] != m + k + 1 or abs(got["fp"]) > 1e-8:
            raise AssertionError(
                f"splrep ier={got['ier']} n={got['n']} fp={got['fp']}")
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
    # (1, 1, 1, 1) makes gfortran -O3 -march=native stop with info 1 and a
    # residual of 6.5. (1.5, 1, 1, 2) reaches the generating parameters
    # (2, 0.5, 0.5, 3) with info 2 on every build tried here.
    x0 = np.array([1.5, 1.0, 1.0, 2.0], dtype=np.float64)
    x_true = np.array([2.0, 0.5, 0.5, 3.0], dtype=np.float64)

    def lmdif():
        xfit = np.array(x0, copy=True)
        info, nfev, ssq = module.bench_lmdif(lm, xfit)
        return int(info), int(nfev), float(ssq), xfit

    def check_lmdif():
        info, nfev, ssq, xfit = lmdif()
        xerr = float(np.max(np.abs(xfit - x_true)))
        # info 2 is the xtol stop at a real iterate. info 1 can fire while
        # the residual is still O(1), which is not the fit of the data.
        if info != 2 or ssq > 1e-12 or xerr > 1e-6:
            raise AssertionError(
                f"lmdif info={info} nfev={nfev} ssq={ssq} xerr={xerr} x={xfit}")
        return f"info={info} nfev={nfev} ssq={ssq:.3e} xerr={xerr:.3e}"

    nrep_h = 2000

    def hybrd():
        info, nfev, xmax = module.bench_hybrd(nrep_h)
        return int(info), int(nfev), float(xmax)

    def check_hybrd():
        info, nfev, xmax = hybrd()
        # Powell's singular function, root at the origin. info 1 is the
        # tolerance stop and info 4 is the singular-Jacobian stop, both only
        # after x is already there. Any other info is an early exit.
        if info not in (1, 4) or xmax > 1e-8:
            raise AssertionError(f"hybrd info={info} nfev={nfev} xmax={xmax}")
        return f"info={info} nfev={nfev} xmax={xmax:.3e}"

    nrep_fft = 20

    def rfft():
        err_pow2, err_gen = module.bench_rfft(nrep_fft)
        return float(err_pow2), float(err_gen)

    def check_rfft():
        err_pow2, err_gen = rfft()
        # Single-precision rfftb(rfftf(x))/n. gfortran's round trip on both
        # lengths stays well under 1e-4 for this O(1) signal.
        if err_pow2 > 1e-5 or err_gen > 1e-5:
            raise AssertionError(
                f"rfft err_pow2={err_pow2} err_gen={err_gen}")
        return f"err_pow2={err_pow2:.3e} err_n60000={err_gen:.3e}"

    nrep_q = 20000

    def dqags():
        result, abserr, neval, ier = module.bench_dqags(nrep_q)
        return float(result), float(abserr), int(neval), int(ier)

    def check_dqags():
        result, abserr, neval, ier = dqags()
        # nrep integrals of 1/sqrt(x) on (0, 1), each equal to 2.
        err = abs(result / nrep_q - 2.0)
        # This integrand takes 231 evaluations per integral. A run that
        # returns 2 with a handful of samples is not the same quadrature.
        if ier != 0 or err > 1e-8 or neval != nrep_q * 231:
            raise AssertionError(
                f"dqags ier={ier} mean={result / nrep_q} abserr={abserr} neval={neval}")
        return f"ier={ier} err={err:.3e} neval={neval}"

    rn_rb = 1000

    def setulb():
        f, nfg, info = module.bench_setulb(rn_rb)
        return float(f), int(nfg), int(info)

    def check_setulb():
        f, nfg, info = setulb()
        # factr 1e7 stops near the Rosenbrock minimum, which is below 1e-8
        # here. info 0 with f = 1e-3 is an early CONV and must not pass.
        if info != 0 or f > 1e-6 or nfg < 1000:
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
        # A handful of Arnoldi steps cannot land on these eigenvalues.
        if info != 0 or err > 1e-8 or niter < 200:
            raise AssertionError(
                f"dsaupd info={info} niter={niter} max_abs_err={err} evals={evals}")
        return f"info={info} niter={niter} max_abs_err={err:.3e}"

    # Stiff Robertson problem, one shot to t = 1e4. Reference values are
    # gfortran -O3 -ffast-math -march=native at rtol 1e-6, atol 1e-8.
    nrep_ode = 40

    def lsoda():
        y1, y2, y3, istate, nst, nfe = module.bench_lsoda(nrep_ode)
        return (float(y1), float(y2), float(y3), int(istate), int(nst), int(nfe))

    def check_lsoda():
        y1, y2, y3, istate, nst, nfe = lsoda()
        # One shot of Robertson to 1e4 takes hundreds of steps. istate 2
        # with the initial state, or with almost no evaluations, is not it.
        if istate != 2 or nfe < nrep_ode * 50:
            raise AssertionError(
                f"lsoda istate={istate} nst={nst} nfe={nfe} y=({y1}, {y2}, {y3})")
        if abs(y1 - 0.10730007) > 1.0e-5 or abs(y3 - 0.89269945) > 1.0e-5 \
                or abs(y2 - 4.80015e-7) > 1.0e-9:
            raise AssertionError(
                f"lsoda istate={istate} nst={nst} nfe={nfe} y=({y1}, {y2}, {y3})")
        return (f"istate={istate} nfe={nfe} nst={nst} "
                f"y1={y1:.6e} y2={y2:.3e} y3={y3:.6e}")

    nrep_odr = 400

    def odr():
        info, nfev, b1, b2 = module.bench_odr(nrep_odr)
        return int(info), int(nfev), float(b1), float(b2)

    def check_odr():
        info, nfev, b1, b2 = odr()
        berr = max(abs(b1 - 1.0), abs(b2 - 2.0))
        # Explicit ODR of y = 1 + 2x. info 2 is the parameter stop at that
        # line. info outside 1..3, or a handful of residual evaluations,
        # is not the fit.
        if info < 1 or info > 3 or berr > 1e-8 or nfev < nrep_odr * 8:
            raise AssertionError(
                f"odr info={info} nfev={nfev} b1={b1} b2={b2}")
        return f"info={info} nfev={nfev} berr={berr:.3e}"

    nrep_id = 80

    def idist():
        krank, nfev, recon = module.bench_id(nrep_id)
        return int(krank), int(nfev), float(recon)

    def check_id():
        krank, nfev, recon = idist()
        # Rank-8 matrix, fixed-rank ID, reconstruction against the original.
        if krank != 8 or nfev != nrep_id or recon > 1e-8:
            raise AssertionError(
                f"id krank={krank} nfev={nfev} recon={recon}")
        return f"nfev={nfev} krank={krank} recon={recon:.3e}"

    nrep_idx = 200

    def idextra():
        info, nsv, fft_err, svd_err = module.bench_id_extra(nrep_idx)
        return int(info), int(nsv), float(fft_err), float(svd_err)

    def check_idextra():
        info, nsv, fft_err, svd_err = idextra()
        # dfftb(dfftf(x)) is n*x, and the 16x8 diagonal has singular
        # values 4 and 3. ier outside 0, or a short run, is not that work.
        if info != 0 or nsv != nrep_idx or fft_err > 1e-10 or svd_err > 1e-8:
            raise AssertionError(
                f"idextra info={info} nsv={nsv} fft_err={fft_err} svd_err={svd_err}")
        return f"info={info} nfev={nsv} fft_err={fft_err:.3e} svd_err={svd_err:.3e}"

    nrep_pp = 250

    def propack():
        info, nfev, serr = module.bench_propack(nrep_pp)
        return int(info), int(nfev), float(serr)

    def check_propack():
        info, nfev, serr = propack()
        # Four singular values of a diagonal with a gap. info 0 and a
        # short matvec count is the Krylov limit, not a converged run.
        if info != 0 or serr > 1e-6 or nfev < nrep_pp * 16:
            raise AssertionError(
                f"propack info={info} nfev={nfev} sigma_err={serr}")
        return f"info={info} nfev={nfev} sigma_err={serr:.3e}"

    return {
        "triple_loop": (triple, check_triple),
        "reduction": (reduce, check_reduce),
        "fitpack_splrep": (splrep, check_splrep),
        "fitpack_splev": (splev, check_splev),
        "minpack_lmdif": (lmdif, check_lmdif),
        "minpack_hybrd": (hybrd, check_hybrd),
        "fftpack_rfft": (rfft, check_rfft),
        "quadpack_dqags": (dqags, check_dqags),
        "lbfgsb_setulb": (setulb, check_setulb),
        "arpack_dsaupd": (dsaupd, check_dsaupd),
        "odepack_lsoda": (lsoda, check_lsoda),
        "odrpack_dodr": (odr, check_odr),
        "id_dist_id": (idist, check_id),
        "id_dist_extra": (idextra, check_idextra),
        "propack_lansvd": (propack, check_propack),
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
        "only": ["bench_lmdif", "bench_hybrd"],
        "scipy": "minpack",
        "blas": False,
        "calls": ["minpack_lmdif", "minpack_hybrd"],
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
    {
        "name": "odepack",
        "driver": SRC / "odepack_bench.f90",
        "only": ["bench_lsoda"],
        "scipy": "odepack",
        "blas": True,
        "calls": ["odepack_lsoda"],
    },
    {
        "name": "fftpack",
        "driver": SRC / "fftpack_bench.f90",
        "only": ["bench_rfft"],
        "scipy": "fftpack",
        "blas": False,
        "calls": ["fftpack_rfft"],
    },
    {
        "name": "odrpack",
        "driver": SRC / "odrpack_bench.f90",
        "only": ["bench_odr"],
        "scipy": "odrpack",
        "blas": True,
        "calls": ["odrpack_dodr"],
    },
    {
        "name": "id_dist",
        "driver": SRC / "id_dist_bench.f90",
        "only": ["bench_id", "bench_id_extra"],
        "scipy": "id_dist",
        "blas": True,
        "cast": True,
        "calls": ["id_dist_id", "id_dist_extra"],
    },
    {
        "name": "propack",
        "driver": SRC / "propack_bench.f90",
        "only": ["bench_propack"],
        "scipy": "propack",
        "blas": True,
        "include": ["scipy/sparse/linalg/_propack/PROPACK/double"],
        "calls": ["propack_lansvd"],
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
        ("gfortran-O3-march", [
            "-O3", "-march=native", "-fPIC", "-std=legacy",
        ]),
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
        "gfortran_O3_march": compilers[4][1],
        "gfortran_O3_native": compilers[5][1],
        "repeats": REPEATS,
        "warmup": WARMUP,
        "cpu": "pinned to logical cpu 0, compilers interleaved each repeat",
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
            ready = []
            notes = {}
            fns = {}
            for compiler, _flags in compilers:
                info = built[f"{spec['name']}:{compiler}"]
                slot = results["workloads"][call].setdefault(compiler, {})
                if info.get("error"):
                    slot["error"] = info["error"]
                    print(f"SKIP {call} {compiler}", flush=True)
                    continue
                fn, check = info["cases"][call]
                try:
                    notes[compiler] = check()
                except Exception as exc:
                    slot["error"] = str(exc)
                    print(f"  CHECK FAIL {call} {compiler}: {exc}", flush=True)
                    continue
                fns[compiler] = fn
                ready.append(compiler)
            if not ready:
                continue
            print(f"RUN {call} interleaved {', '.join(ready)}", flush=True)
            samples = {name: [] for name in ready}
            ncomp = len(ready)
            for i in range(WARMUP + REPEATS):
                shift = i % ncomp
                order = ready[shift:] + ready[:shift]
                for name in order:
                    t0 = time.perf_counter()
                    fns[name]()
                    if i >= WARMUP:
                        samples[name].append(time.perf_counter() - t0)
            for name in ready:
                slot = results["workloads"][call][name]
                stats = summarize(samples[name])
                slot.update(stats)
                slot["check"] = notes[name]
                slot["error"] = None
                per_work = ""
                work = _note_work(notes[name])
                if work:
                    key, count = work
                    sec = stats["median_s"] / count
                    slot["work_key"] = key
                    slot["work_count"] = count
                    slot["sec_per_work"] = sec
                    per_work = f"  {sec * 1e6:.3f}us/{key}"
                print(
                    f"  {name} median {stats['median_s']:.6f}s{per_work}  "
                    f"iqr {stats['iqr_s']:.6f}s  {notes[name]}",
                    flush=True)

    # Ratios. Profile when --fast is >1.5x the matched native fast-math gfortran.
    profiles = {}
    ratio_pairs = (
        ("lfortran", "gfortran-O2", "ratio_lfortran_over_O2"),
        ("lfortran", "gfortran-O3", "ratio_lfortran_over_O3"),
        ("lfortran", "gfortran-O3-native", "ratio_lfortran_over_O3_native"),
        ("lfortran-nofast", "gfortran-O3", "ratio_nofast_over_O3"),
        ("lfortran-nofast", "gfortran-O3-native", "ratio_nofast_over_O3_native"),
        ("lfortran-nofast", "gfortran-O3-march", "ratio_nofast_over_O3_march"),
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
                "nofast_over_march": slot.get("ratio_nofast_over_O3_march"),
            }
            for call, slot in results["workloads"].items()
        },
    }, indent=2))


if __name__ == "__main__":
    main()
