# f2py benchmark

`bench_f2py.py` times one call into an f2py extension. Compilers share
one core. Each repeat runs every compiler once, in rotating order, after
three warmup rounds of the same shape. The reported time is the median
of 25 repeats.

## Columns

A ratio is LFortran's median divided by gfortran's. Below 1, LFortran
is faster.

| column | numerator | denominator |
|---|---|---|
| lf/O2 | `--fast` | `-O2` |
| lf/O3 | `--fast` | `-O3` |
| lf/O3n | `--fast` | `-O3 -march=native -ffast-math -funroll-loops` |
| lf-nf/O3 | `--fast --no-fast-math` | `-O3` |
| lf-nf/O3n | `--fast --no-fast-math` | `-O3 -march=native -ffast-math -funroll-loops` |
| lf-nf/strict | `--fast --no-fast-math` | `-O3 -march=native -ffp-contract=off` |

Every gfortran line also passes `-fPIC -std=legacy`. `--fast` is
LFortran's fast math, native CPU, and LLVM `-O3`. `--no-fast-math`
keeps the rest of `--fast` and turns fast math off.

gfortran contracts a multiply and an add into an FMA by default
(`-ffp-contract=fast`) even when `-ffast-math` is off. `-ffast-math`
is on for lf and for O3n only. O2, O3, and lf-nf do not pass
`-ffast-math`, but O2 and O3 still contract. lf-nf/strict is the
like-for-like native comparison: same width, contraction off on the
gfortran side. lf-nf/O3n is strict LFortran against gfortran with
`-ffast-math`, so a gap there can be reassociation rather than a
missed instruction.

The check string next to each median is the work count for that call
(`nfev`, `neval`, `nfg`, `niter`, `nfe`, or `n`) when the workload
has one. The same count on both sides of a ratio means the times are
for the same number of steps.

The columns cover every workload: the triple loop and reduction,
fitpack `curfit`/`splev`, MINPACK `lmdif` and `hybrd1`, quadpack
`dqags`, L-BFGS-B `setulb`, ARPACK `dsaupd`, ODEPACK `lsoda`, FFTPACK
`rfftf`/`rfftb`, ODRPACK `dodr`, the rank-8 `id_dist` interpolative
decomposition, and PROPACK `dlansvd`.
