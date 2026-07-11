// Drives the shipped LCompilers::math_c_runtime_symbol (libasr/math_backend.h).
// Build (from repo root or with -I to src):
//   c++ -std=c++17 -I src -o test_math_symbol \
//       src/runtime/pure/tests/test_math_c_runtime_symbol.cpp
#include <cassert>
#include <iostream>
#include <string>

#include <libasr/math_backend.h>

int main() {
    using LCompilers::math_c_runtime_symbol;
    using LCompilers::math_backend_policy;

    assert(math_c_runtime_symbol("sin", 8, false, "libm") == "_lfortran_dsin");
    assert(math_c_runtime_symbol("cos", 8, false, "libm") == "_lfortran_dcos");
    assert(math_c_runtime_symbol("sin", 4, false, "libm") == "_lfortran_ssin");
    assert(math_c_runtime_symbol("sin", 8, false, "pure") == "_lfortran_pure_dsin");
    assert(math_c_runtime_symbol("cos", 8, false, "pure") == "_lfortran_pure_dcos");
    assert(math_c_runtime_symbol("sin", 4, false, "pure") == "_lfortran_pure_ssin");
    assert(math_c_runtime_symbol("sin", 8, true, "pure") == "_lfortran_zsin");
    assert(math_c_runtime_symbol("exp", 8, false, "pure") == "_lfortran_dexp");
    using LCompilers::math_c_runtime_bulk_symbol;
    assert(math_c_runtime_bulk_symbol("sin", 8, false, "pure") == "_lfortran_pure_dsin_v");
    assert(math_c_runtime_bulk_symbol("cos", 8, false, "pure") == "_lfortran_pure_dcos_v");
    assert(math_c_runtime_bulk_symbol("sin", 4, false, "pure") == "");
    assert(math_c_runtime_bulk_symbol("sin", 8, false, "libm") == "");
    assert(math_c_runtime_bulk_symbol("sin", 8, true, "pure") == "");

    // policy default + mutation (compile-time selection for a pass)
    assert(math_backend_policy() == "libm"
        || math_backend_policy() == "pure");
    math_backend_policy() = "pure";
    assert(math_c_runtime_symbol("sin", 8, false) == "_lfortran_pure_dsin");
    math_backend_policy() = "libm";
    assert(math_c_runtime_symbol("sin", 8, false) == "_lfortran_dsin");

    std::cout << "PASS math_c_runtime_symbol (shipped libasr/math_backend.h)\n";
    return 0;
}
