#!/usr/bin/env python3
"""Production-shaped pure vs host metrics.

Scalar: external pure ABI vs external host sin (C ABI). No whole-program
optimization into the bench (matches LFortran link of the pure archive).
Array: pure_dsin_v bulk vs host y=sin(x); also legacy N x pure_dsin loop.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path


def repo_root() -> Path:
    here = Path(__file__).resolve()
    for parent in (here.parents[i] for i in range(3, 8)):
        if (parent / "src/runtime/pure/lfortran_intrinsic_trig.f90").is_file():
            return parent
    return here.parents[5]


def run(cmd, cwd=None, env=None) -> str:
    print("+", " ".join(str(c) for c in cmd), flush=True)
    r = subprocess.run(cmd, cwd=cwd, env=env, text=True, capture_output=True)
    sys.stdout.write(r.stdout or "")
    if r.returncode != 0:
        sys.stderr.write(r.stderr or "")
        raise SystemExit(r.returncode)
    return r.stdout or ""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--lfortran", default=os.environ.get("LFORTRAN", ""))
    ap.add_argument("--skip-lfortran", action="store_true")
    args = ap.parse_args()
    out = args.out_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    fig = out / "figures"
    fig.mkdir(exist_ok=True)
    root = repo_root()
    pure = root / "src/runtime/pure"
    metrics_dir = Path(__file__).resolve().parent
    work = out / "build"
    work.mkdir(exist_ok=True)
    log_lines: list[str] = []

    def log(msg: str) -> None:
        print(msg, flush=True)
        log_lines.append(msg)

    gfortran = shutil.which("gfortran")
    if not gfortran:
        raise SystemExit("gfortran required")

    # Vectorization ON (auto-vec). No OpenMP SIMD: measured slower than plain
    # do-loops on this path; host still gets libmvec on array-expr sin(x).
    gflags = [
        "-ffree-line-length-none",
        "-O3",
        "-march=native",
        "-ftree-vectorize",
        "-funroll-loops",
        "-ffp-contract=fast",
        "-fno-math-errno",
        "-fPIC",
    ]
    # No -flto: production LFortran does not LTO-inline pure into user code.
    log("LTO no (production-shaped external ABI; pure linked from .a)")
    log("AUTO_VEC yes for array-expr host; pure external calls uninlined")
    has_omp = False

    objs = work / "objs"
    objs.mkdir(exist_ok=True)
    trig = pure / "lfortran_intrinsic_trig.f90"
    abi = pure / "lfortran_pure_math_abi.f90"
    bench = metrics_dir / "bench_simd.f90"

    run([gfortran, *gflags, f"-J{objs}", "-c", str(trig), "-o", str(objs / "trig.o")])
    run([
        gfortran, *gflags, f"-J{objs}", f"-I{objs}",
        "-c", str(abi), "-o", str(objs / "abi.o"),
    ])
    archive = work / "liblfortran_runtime_pure_math.a"
    run(["ar", "rcs", str(archive), str(objs / "trig.o"), str(objs / "abi.o")])
    log(f"ARCHIVE {archive} size={archive.stat().st_size}")

    prefix = work / "kernel"
    bin_path = work / "bench_simd"
    run(
        [
            gfortran,
            *gflags,
            f"-I{objs}",
            str(bench),
            f"-L{work}",
            "-llfortran_runtime_pure_math",
            "-o",
            str(bin_path),
            "-lm",
        ]
    )
    outb = run([str(bin_path), str(prefix)])
    log(outb.rstrip())

    acc = (work / "kernel_accuracy.txt").read_text()
    tim = (work / "kernel_timing.txt").read_text()
    log("--- accuracy ---\n" + acc)
    log("--- timing ---\n" + tim)

    acc_map = {}
    for line in acc.splitlines():
        p = line.split()
        if len(p) >= 3 and p[0] in ("max_abs", "n_gt_1e-15", "n_gt_1e-10"):
            acc_map[p[0]] = (float(p[1]), float(p[2]))
        if p and p[0] == "n_grid":
            n_grid = int(p[1])
    n_grid = acc_map.get("n_grid", 4001) if False else int(
        [l.split()[1] for l in acc.splitlines() if l.startswith("n_grid")][0]
    )

    times = {}
    for line in tim.splitlines()[1:]:
        p = line.split()
        if len(p) >= 2:
            times[p[0]] = float(p[1])

    # Primary speed metric: external pure ABI vs external host sin
    pure_sl = times.get("pure_scalar_loop", float("nan"))
    host_sl = times.get("host_scalar_loop", float("nan"))
    ratio_scalar_loop = times.get(
        "ratio_pure_scalar_loop_over_host",
        pure_sl / host_sl if host_sl and host_sl > 0 else float("nan"),
    )
    host_a = times.get("host_array_expr", times.get("host_array", float("nan")))
    pure_bulk = times.get(
        "pure_array_bulk",
        times.get("pure_elemental_array", float("nan")),
    )
    pure_legacy = times.get("pure_array_scalar_loop", float("nan"))
    ratio_bulk = times.get(
        "ratio_pure_array_bulk_over_host",
        pure_bulk / host_a if host_a and host_a > 0 else float("nan"),
    )
    ratio_legacy = times.get(
        "ratio_pure_array_scalar_loop_over_host",
        pure_legacy / host_a if host_a and host_a > 0 else float("nan"),
    )
    # aliases for older keys
    pure_e = pure_bulk
    pure_v = pure_bulk
    ratio_elem = ratio_bulk
    ratio_simd = ratio_bulk
    ratio_bindc = times.get("ratio_pure_bindc_over_host_scalar", float("nan"))
    ratio_best_array = ratio_bulk
    ratio_best = min(ratio_scalar_loop, ratio_best_array)

    # plot
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        def load(path):
            xs, es = [], []
            for line in path.read_text().splitlines():
                a = line.split()
                if len(a) >= 2:
                    xs.append(float(a[0]))
                    es.append(max(float(a[1]), 1e-18))
            return xs, es

        xs, es = load(work / "kernel_sin_err.dat")
        xc, ec = load(work / "kernel_cos_err.dat")
        fig, axes = plt.subplots(2, 1, figsize=(9, 5.5), sharex=True)
        for ax, x, e, title in [
            (axes[0], xs, es, r"pure $\sin$ abs error vs host"),
            (axes[1], xc, ec, r"pure $\cos$ abs error vs host"),
        ]:
            ax.semilogy(x, e, lw=0.65, color="#1f4e79")
            ax.axhline(1e-15, color="#c44e52", ls="--", lw=1, label=r"$10^{-15}$")
            ax.axhline(1e-10, color="#dd8452", ls=":", lw=1, label=r"$10^{-10}$")
            ax.set_ylabel("abs err")
            ax.set_title(title, loc="left")
            ax.set_ylim(1e-18, 1e-8)
            ax.grid(True, which="both", alpha=0.3)
            ax.legend(fontsize=8)
        axes[1].set_xlabel(r"$x \in [-20,20]$")
        fig.tight_layout()
        fig.savefig(fig / "pure_abs_error.png", dpi=140, bbox_inches="tight")
        log(f"FIGURE {fig / 'pure_abs_error.png'}")
    except Exception as e:
        log(f"FIGURE_SKIP {e}")

    # lfortran symbol identity
    lfortran = args.lfortran.strip() or str(Path.home() / ".local/lfortran-pure/bin/lfortran")
    sym_section = "lfortran not run\n"
    if not args.skip_lfortran and Path(lfortran).is_file():
        env = os.environ.copy()
        libdir = str(Path(lfortran).resolve().parent.parent / "lib")
        env["LD_LIBRARY_PATH"] = libdir + ":" + env.get("LD_LIBRARY_PATH", "")
        src = work / "user_math.f90"
        src.write_text(
            "program u\nimplicit none\nreal(8)::x,s\nx=1.5d0\ns=sin(x)\nprint *, s\nend\n"
        )
        run([lfortran, str(src), "-o", str(work / "user_libm")], env=env)
        run(
            [lfortran, "--math-backend=pure", str(src), "-o", str(work / "user_pure")],
            env=env,
        )
        nm_l = subprocess.check_output(["nm", "-u", str(work / "user_libm")], text=True)
        nm_p = subprocess.check_output(["nm", str(work / "user_pure")], text=True)
        (out / "symbol_identity.log").write_text(
            "=== nm -u default ===\n"
            + nm_l
            + "\n=== nm pure (defs) ===\n"
            + "\n".join(l for l in nm_p.splitlines() if "pure_d" in l or "lfortran_d" in l)
            + "\n"
        )
        log((out / "symbol_identity.log").read_text())
        sym_section = (
            f"default has U _lfortran_dsin: {'_lfortran_dsin' in nm_l}\n"
            f"pure defines T _lfortran_pure_dsin: {'_lfortran_pure_dsin' in nm_p}\n"
        )
    else:
        (out / "symbol_identity.log").write_text("skipped\n")

    max_s, max_c = acc_map["max_abs"]
    n10s, n10c = acc_map["n_gt_1e-10"]
    n15s, n15c = acc_map["n_gt_1e-15"]

    win_scalar = ratio_scalar_loop < 1.0
    win_array = ratio_bulk < 1.0
    speed_line = (
        f"Scalar external pure/host = **{ratio_scalar_loop:.3f}**"
        + (" (pure faster)." if win_scalar else ".")
        + f" Array bulk `pure_dsin_v`/host = **{ratio_bulk:.3f}**"
        + (" (pure faster than host array path)." if win_array else ".")
        + f" Legacy N×`pure_dsin` loop/host = **{ratio_legacy:.3f}**."
        + f" bind(c) scalar ratio **{ratio_bindc:.3f}**."
    )

    md = f"""# Pure math backend metrics

Generated by `src/runtime/pure/tests/metrics/run_metrics.py`.

## Method

| Item | Value |
|------|--------|
| Accuracy grid | x ∈ [-20, 20], n = {n_grid} (pure ABI vs host C `sin` / Fortran `cos`) |
| Scalar timing | external `_lfortran_pure_dsin` vs bind(c) `sin` on [0, 1.5] |
| Array timing | bulk `pure_dsin_v` and legacy N×`pure_dsin` vs host `y=sin(x)` on [-1.5, 1.5] |
| Flags | `{" ".join(gflags)}` (no LTO; archive link) |
| Note | Host array path may use vector math library; pure bulk is pure Fortran |

## Accuracy

| Metric | sin | cos |
|--------|-----|-----|
| max abs | {max_s:.6e} | {max_c:.6e} |
| count > 1e-15 | {int(n15s)} | {int(n15c)} |
| count > 1e-10 | {int(n10s)} | {int(n10c)} |

## Performance

### Primary — scalar ABI-to-ABI (pure vs host libm, both bind(c))

| Path | seconds | ratio pure/host |
|------|---------|-----------------|
| pure `_lfortran_pure_dsin` loop | {pure_sl:.6e} | {ratio_scalar_loop:.3f} |
| host C `sin` loop | {host_sl:.6e} | 1.000 |
| pure ns/call | {times.get("pure_ns_per_call", float("nan")):.3f} | |
| host C `sin` ns/call | {times.get("host_ns_per_call", float("nan")):.3f} | |

### Secondary — array

| Path | seconds | ratio vs host array-expr |
|------|---------|--------------------------|
| host array-expr `y=sin(x)` | {host_a:.6e} | 1.000 |
| pure bulk `pure_dsin_v` | {pure_bulk:.6e} | {ratio_bulk:.3f} |
| legacy N×`pure_dsin` loop | {pure_legacy:.6e} | {ratio_legacy:.3f} |

{speed_line}

## Symbol identity

{sym_section}

## Artifacts

- `build/kernel_accuracy.txt`, `build/kernel_timing.txt`, `*_err.dat`
- `figures/pure_abs_error.png` when matplotlib is available
- `symbol_identity.log`, `metrics_run.log`
"""
    (out / "metrics.md").write_text(md)
    (out / "metrics_run.log").write_text("\n".join(log_lines) + "\n")
    print(f"WROTE {out / 'metrics.md'} scalar_loop_ratio={ratio_scalar_loop:.4f} array_best={ratio_best_array:.4f}", flush=True)
    # exit non-zero if speed goal failed? keep 0 for report; verifier checks md
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
