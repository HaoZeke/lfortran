/* Pure Sollya math backend ABI (compile-time selection via --math-backend=pure). */
#ifndef LFORTRAN_PURE_MATH_H
#define LFORTRAN_PURE_MATH_H

#ifdef __cplusplus
extern "C" {
#endif

double _lfortran_pure_dsin(double x);
double _lfortran_pure_dcos(double x);
float  _lfortran_pure_ssin(float x);
float  _lfortran_pure_scos(float x);

#ifdef __cplusplus
}
#endif

#endif
