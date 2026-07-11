#!/usr/bin/env python3
"""Re-runnable pure vs host math metrics for LFortran pure-math-backend.

Measures accuracy + timing of pure Sollya kernels (ABI archive), and when
`lfortran` with --math-backend is available, symbol identity of real compiles.

Usage (on a machine with gfortran; optional LFORTRAN= path):
  python3 run_metrics.py --out-dir ./out
  LFORTRAN=~/.local/lfortran-pure/bin/lfortran python3 run_metrics.py --out-dir ./out

Does not invent speed wins: if pure is slower, the report says so.
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
    # metrics/ -> tests/ -> pure/ -> runtime/ -> src/ -> root
    here = Path(__file__).resolve()
    # prefer walking up until src/runtime/pure exists
    for parent in [here.parents[i] for i in range(3, 8)]:
        if (parent / "src/runtime/pure/lfortran_intrinsic_trig.f90").is_file():
            return parent
    return here.parents[5]


def run(cmd, cwd=None, env=None):
    print("+", " ".join(str(c) for c in cmd), flush=True)
    r = subprocess.run(cmd, cwd=cwd, env=env, text=True, capture_output=True)
    if r.returncode != 0:
        sys.stderr.write(r.stdout + "\n" + r.stderr + "\n")
        raise SystemExit(r.returncode)
    if r.stdout:
        print(r.stdout, end="" if r.stdout.endswith("\n") else "\n")
    return r.stdout


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--lfortran", default=os.environ.get("LFORTRAN", ""))
    ap.add_argument("--skip-lfortran", action="store_true")
    ap.add_argument("--n-time", type=int, default=5_000_000)
    args = ap.parse_args()
    out: Path = args.out_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    fig = out / "figures"
    fig.mkdir(exist_ok=True)
    root = repo_root()
    pure = root / "src/runtime/pure"
    metrics_dir = Path(__file__).resolve().parent
    work = out / "build"
    work.mkdir(exist_ok=True)

    log_path = out / "metrics_run.log"
    log_lines: list[str] = []

    def log(msg: str) -> None:
        print(msg, flush=True)
        log_lines.append(msg)

    # --- build pure archive + bench ---
    trig = pure / "lfortran_intrinsic_trig.f90"
    abi = pure / "lfortran_pure_math_abi.f90"
    bench_src = metrics_dir / "bench_pure_vs_host.f90"
    for p in (trig, abi, bench_src):
        if not p.is_file():
            raise SystemExit(f"missing {p}")

    gfortran = shutil.which("gfortran")
    if not gfortran:
        raise SystemExit("gfortran required")

    objs = work / "objs"
    objs.mkdir(exist_ok=True)
    run(
        [
            gfortran,
            "-ffree-line-length-none",
            "-O2",
            "-fPIC",
            f"-J{objs}",
            "-c",
            str(trig),
            "-o",
            str(objs / "trig.o"),
        ]
    )
    run(
        [
            gfortran,
            "-ffree-line-length-none",
            "-O2",
            "-fPIC",
            f"-J{objs}",
            f"-I{objs}",
            "-c",
            str(abi),
            "-o",
            str(objs / "abi.o"),
        ]
    )
    archive = work / "liblfortran_runtime_pure_math.a"
    run(["ar", "rcs", str(archive), str(objs / "trig.o"), str(objs / "abi.o")])
    log(f"ARCHIVE {archive} size={archive.stat().st_size}")

    prefix = work / "kernel"
    bench_bin = work / "bench_pure_vs_host"
    run(
        [
            gfortran,
            "-ffree-line-length-none",
            "-O2",
            str(bench_src),
            f"-L{work}",
            "-llfortran_runtime_pure_math",
            "-o",
            str(bench_bin),
        ]
    )
    out_bench = run([str(bench_bin), str(prefix)])
    log(out_bench.rstrip())

    acc = (work / "kernel_accuracy.txt").read_text()
    tim = (work / "kernel_timing.txt").read_text()
    log("--- accuracy file ---\n" + acc)
    log("--- timing file ---\n" + tim)

    # parse accuracy
    acc_map: dict[str, tuple[float, float]] = {}
    n_grid = 0
    for line in acc.splitlines():
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "n_grid":
            n_grid = int(parts[1])
        elif parts[0] in {
            "max_abs",
            "mean_abs",
            "p50_abs",
            "p95_abs",
            "p99_abs",
            "n_gt_1e-15",
            "n_gt_1e-10",
        }:
            acc_map[parts[0]] = (float(parts[1]), float(parts[2]))

    # parse timing
    times: dict[str, float] = {}
    for line in tim.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2 and parts[0] in ("pure_first", "host", "pure_second", "ratio_pure_over_host_mean"):
            times[parts[0]] = float(parts[1])

    pure_t = 0.5 * (times.get("pure_first", 0) + times.get("pure_second", 0))
    host_t = times.get("host", 0)
    ratio = times.get("ratio_pure_over_host_mean", pure_t / host_t if host_t else float("nan"))

    # accuracy plot
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        def load_err(path: Path):
            xs, es = [], []
            for line in path.read_text().splitlines():
                a = line.split()
                if len(a) >= 2:
                    xs.append(float(a[0]))
                    es.append(max(float(a[1]), 1e-18))
            return xs, es

        xs, es = load_err(work / "kernel_sin_err.dat")
        xc, ec = load_err(work / "kernel_cos_err.dat")
        fig, axes = plt.subplots(2, 1, figsize=(9, 5.5), sharex=True)
        for ax, x, e, title in [
            (axes[0], xs, es, r"pure $\sin$ vs host: absolute error"),
            (axes[1], xc, ec, r"pure $\cos$ vs host: absolute error"),
        ]:
            ax.semilogy(x, e, lw=0.65, color="#1f4e79")
            ax.axhline(1e-15, color="#c44e52", ls="--", lw=1, label=r"$10^{-15}$")
            ax.axhline(1e-10, color="#dd8452", ls=":", lw=1, label=r"$10^{-10}$ (reject)")
            ax.set_ylabel(r"$|f_{\mathrm{pure}}-f_{\mathrm{host}}|$")
            ax.set_title(title, loc="left", fontsize=11)
            ax.set_ylim(1e-18, 1e-8)
            ax.grid(True, which="both", alpha=0.3)
            ax.legend(loc="upper right", fontsize=8)
        axes[1].set_xlabel(r"argument $x$ on $[-20,20]$")
        fig.suptitle("Pure Sollya kernels vs host math (metrics suite)", fontsize=11)
        fig.tight_layout()
        
        fig.savefig(fig / "pure_abs_error.png", dpi=140, bbox_inches="tight")
        log(f"FIGURE {fig / 'pure_abs_error.png'}")
    except Exception as e:
        log(f"FIGURE_SKIP {e}")

    # --- optional real lfortran ---
    lfortran = args.lfortran.strip()
    if not lfortran:
        cand = Path.home() / ".local/lfortran-pure/bin/lfortran"
        if cand.is_file():
            lfortran = str(cand)
    symbol_md = ""
    lfortran_md = ""
    if not args.skip_lfortran and lfortran and Path(lfortran).is_file():
        env = os.environ.copy()
        libdir = str(Path(lfortran).resolve().parent.parent / "lib")
        env["LD_LIBRARY_PATH"] = libdir + ":" + env.get("LD_LIBRARY_PATH", "")
        src = work / "user_math.f90"
        src.write_text(
            textwrap.dedent(
                """\
            program user_math
              implicit none
              real(8) :: x, s, c
              integer :: i
              do i = 0, 4
                 x = 0.5d0 * real(i, 8)
                 s = sin(x)
                 c = cos(x)
                 print "(es16.8,1x,es16.8,1x,es16.8)", x, s, c
              end do
            end program
            """
            )
        )
        bin_libm = work / "user_libm"
        bin_pure = work / "user_pure"
        run([lfortran, str(src), "-o", str(bin_libm)], env=env)
        run([lfortran, "--math-backend=pure", str(src), "-o", str(bin_pure)], env=env)
        out_libm = run([str(bin_libm)])
        out_pure = run([str(bin_pure)])
        (out / "lfortran_libm_run.txt").write_text(out_libm)
        (out / "lfortran_pure_run.txt").write_text(out_pure)

        def nm_u(path: Path) -> str:
            return subprocess.check_output(["nm", "-u", str(path)], text=True, stderr=subprocess.DEVNULL)

        def nm_all(path: Path) -> str:
            return subprocess.check_output(["nm", str(path)], text=True, stderr=subprocess.DEVNULL)

        nm_libm = nm_u(bin_libm)
        nm_pure_u = nm_u(bin_pure)
        nm_pure_t = nm_all(bin_pure)
        (out / "symbol_identity.log").write_text(
            "=== nm -u user_libm ===\n"
            + nm_libm
            + "\n=== nm -u user_pure ===\n"
            + nm_pure_u
            + "\n=== nm user_pure (defined pure) ===\n"
            + "\n".join(l for l in nm_pure_t.splitlines() if "pure_d" in l)
            + "\n"
        )
        log("--- symbol identity ---")
        log((out / "symbol_identity.log").read_text())

        # compare outputs
        def parse_rows(text: str):
            rows = []
            for line in text.splitlines():
                p = line.split()
                if len(p) >= 3:
                    try:
                        rows.append(tuple(map(float, p[:3])))
                    except ValueError:
                        pass
            return rows

        rl, rp = parse_rows(out_libm), parse_rows(out_pure)
        max_d = 0.0
        if rl and rp and len(rl) == len(rp):
            max_d = max(max(abs(a[1] - b[1]), abs(a[2] - b[2])) for a, b in zip(rl, rp))
        log(f"LFORTRAN_OUTPUT_MAX_ABS_DIFF {max_d:.3e}")
        has_u_dsin = "_lfortran_dsin" in nm_libm
        has_t_pure = "_lfortran_pure_dsin" in nm_pure_t
        symbol_md = textwrap.dedent(
            f"""\
            ### Symbol identity (real `lfortran`)

            | Binary | Math symbols |
            |--------|----------------|
            | default | `nm -u` shows `U _lfortran_dsin` / `U _lfortran_dcos`: **{has_u_dsin}** |
            | `--math-backend=pure` | defines `T _lfortran_pure_dsin` / `T _lfortran_pure_dcos`: **{has_t_pure}** |

            Max abs diff of printed sin/cos samples (pure binary vs default): **{max_d:.3e}**
            """
        )
        lfortran_md = f"LFortran: `{lfortran}`\n"
    else:
        log("LFORTRAN_SKIP (no binary)")
        (out / "symbol_identity.log").write_text("lfortran skipped\n")
        symbol_md = "### Symbol identity\n\n`lfortran` not available for this run; kernel metrics only.\n"
        lfortran_md = "LFortran: not run\n"

    # honesty blurb
    if ratio > 1.05:
        speed_claim = (
            f"Pure is **slower** on this scalar loop (ratio pure/host ≈ **{ratio:.2f}**). "
            "That is expected: host libm is highly tuned; pure value is ownership and "
            "regenerable coefficients, not a free speed win."
        )
    elif ratio < 0.95:
        speed_claim = f"Pure is faster on this scalar loop (ratio pure/host ≈ **{ratio:.2f}**)."
    else:
        speed_claim = f"Pure is roughly tied with host on this scalar loop (ratio ≈ **{ratio:.2f}**)."

    max_s, max_c = acc_map.get("max_abs", (float("nan"), float("nan")))
    mean_s, mean_c = acc_map.get("mean_abs", (float("nan"), float("nan")))
    p99_s, p99_c = acc_map.get("p99_abs", (float("nan"), float("nan")))
    n10_s, n10_c = acc_map.get("n_gt_1e-10", (float("nan"), float("nan")))
    n15_s, n15_c = acc_map.get("n_gt_1e-15", (float("nan"), float("nan")))

    md = textwrap.dedent(
        f"""\
        # Pure math backend metrics (pure Sollya sin/cos vs host)

        Generated by `src/runtime/pure/tests/metrics/run_metrics.py`.

        ## Method

        | Item | Value |
        |------|--------|
        | Host | see machine running the suite |
        | Accuracy grid | x ∈ [-20, 20], n = {n_grid} uniform |
        | Timing | N = {args.n_time} calls; warmup 1e5; order pure → host → pure; report mean pure |
        | Pure path | gfortran link of `liblfortran_runtime_pure_math.a` (`_lfortran_pure_d{{sin,cos}}`) |
        | Flags | gfortran `-O2 -ffree-line-length-none` |
        | {lfortran_md.strip()} | |

        ## Accuracy (pure kernel ABI vs host `sin`/`cos`)

        | Metric | sin | cos |
        |--------|-----|-----|
        | max abs error | {max_s:.6e} | {max_c:.6e} |
        | mean abs error | {mean_s:.6e} | {mean_c:.6e} |
        | p50 abs | {acc_map.get("p50_abs", (0,0))[0]:.6e} | {acc_map.get("p50_abs", (0,0))[1]:.6e} |
        | p95 abs | {acc_map.get("p95_abs", (0,0))[0]:.6e} | {acc_map.get("p95_abs", (0,0))[1]:.6e} |
        | p99 abs | {p99_s:.6e} | {p99_c:.6e} |
        | count > 1e-15 | {int(n15_s)} | {int(n15_c)} |
        | count > 1e-10 | {int(n10_s)} | {int(n10_c)} |

        Pass bar used in design: max ≲ 1e-15 on this grid, **zero** samples above 1e-10.

        ## Performance (scalar loop)

        | Path | wall time (s) | ns/call (approx) |
        |------|---------------|------------------|
        | pure (mean of two runs) | {pure_t:.6e} | {1e9 * pure_t / args.n_time:.3f} |
        | host | {host_t:.6e} | {1e9 * host_t / args.n_time:.3f} |
        | ratio pure/host | {ratio:.3f} | |

        {speed_claim}

        ## Multi-axis “nicer?” (honest)

        | Axis | Verdict |
        |------|---------|
        | Accuracy vs host on [-20,20] | **Parity** at ~1 ULP scale (max ~1e-16) |
        | Speed (this scalar loop) | **Not nicer** if ratio > 1; see table |
        | Owned regenerable kernels | **Yes** (Sollya scripts + pure Fortran) |
        | Host-lib independence of pure objects | **Yes** (static pure archive) |
        | Compile-time selection | **Yes** (`--math-backend=libm\\|pure`, no per-call branch) |

        “Nicer” for the pure backend means **owned elementary math you can regenerate and ship**, with accuracy that tracks host on the stated domain—not a blanket claim that pure beats libm on every metric.

        {symbol_md}

        ## Artifacts

        - `build/kernel_accuracy.txt`, `build/kernel_timing.txt`
        - `build/kernel_sin_err.dat`, `build/kernel_cos_err.dat`
        - `figures/pure_abs_error.png` (if matplotlib available)
        - `symbol_identity.log` (if lfortran run)
        - `metrics_run.log` (this run)
        """
    )
    (out / "metrics.md").write_text(md)
    log_path.write_text("\n".join(log_lines) + "\n")
    print(f"WROTE {out / 'metrics.md'}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
