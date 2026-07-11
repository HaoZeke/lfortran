cmake_minimum_required(VERSION 3.5 FATAL_ERROR)

project(lfortran_runtime_pure C Fortran)

add_library(lfortran_runtime_pure
    STATIC
    lfortran_intrinsic_iso_c_binding.f90
    lfortran_intrinsic_iso_fortran_env.f90
    lfortran_intrinsic_ieee_arithmetic.f90
    lfortran_intrinsic_trig.f90
    lfortran_pure_math_abi.f90
)

# Optional standalone pure math library for --math-backend=pure linking
add_library(lfortran_runtime_pure_math
    STATIC
    lfortran_intrinsic_trig.f90
    lfortran_pure_math_abi.f90
)
