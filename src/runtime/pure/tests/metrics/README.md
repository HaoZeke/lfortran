# Pure vs host metrics

Re-run on a build machine (e.g. rg.terra):

```bash
cd src/runtime/pure/tests/metrics
python3 run_metrics.py --out-dir /path/to/out
# with real lfortran pure install:
LFORTRAN=$HOME/.local/lfortran-pure/bin/lfortran python3 run_metrics.py --out-dir /path/to/out
```

Emits accuracy + timing tables (`metrics.md`), error series, optional plot, and
`symbol_identity.log` when `lfortran --math-backend=pure` is available.
