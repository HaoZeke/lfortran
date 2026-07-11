#ifndef LFORTRAN_PURE_MATH_H
#define LFORTRAN_PURE_MATH_H
#ifdef __cplusplus
extern "C" {
#endif
double _lfortran_pure_dsin(double x);
double _lfortran_pure_dcos(double x);
float  _lfortran_pure_ssin(float x);
float  _lfortran_pure_scos(float x);
void   _lfortran_pure_dsin_v(int n, const double *x, double *y);
void   _lfortran_pure_dcos_v(int n, const double *x, double *y);
#ifdef __cplusplus
}
#endif
#endif
