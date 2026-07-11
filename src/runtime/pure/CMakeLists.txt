cmake_minimum_required(VERSION 3.5 FATAL_ERROR)

# Standalone pure Fortran project (harness / local gfortran demos).
# The installable archive used by `lfortran --math-backend=pure` is built from
# src/runtime/legacy/CMakeLists.txt as liblfortran_runtime_pure_math.a next to
# lfortran_runtime (system gfortran; no circular frontend dependency).
project(lfortran_runtime_pure C Fortran)

add_library(lfortran_runtime_pure
    STATIC
    lfortran_intrinsic_iso_c_binding.f90
    lfortran_intrinsic_iso_fortran_env.f90
    lfortran_intrinsic_ieee_arithmetic.f90
    lfortran_intrinsic_trig.f90
    lfortran_pure_math_abi.f90
)

add_library(lfortran_runtime_pure_math
    STATIC
    lfortran_intrinsic_trig.f90
    lfortran_pure_math_abi.f90
)
install(TARGETS lfortran_runtime_pure_math
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
