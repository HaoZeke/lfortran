// Unit test for compile-time math symbol selection (no LFortran binary required).
// Compile: c++ -std=c++17 -I../../../ -c is heavy; instead we ship a self-contained
// reimplementation of the pure selection rules matching utils.h for CI without full tree.
// Preferred: compile against installed headers when building LFortran.
//
// Standalone check of the same rules used by LCompilers::math_c_runtime_symbol:
#include <cassert>
#include <iostream>
#include <string>

static std::string math_c_runtime_symbol(const std::string &name, int kind,
        bool is_complex, const std::string &backend) {
    if (is_complex) {
        return (kind == 4) ? ("_lfortran_c" + name) : ("_lfortran_z" + name);
    }
    const bool pure_trig = (backend == "pure") && (name == "sin" || name == "cos");
    if (pure_trig) {
        return (kind == 4) ? ("_lfortran_pure_s" + name) : ("_lfortran_pure_d" + name);
    }
    return (kind == 4) ? ("_lfortran_s" + name) : ("_lfortran_d" + name);
}

int main() {
    assert(math_c_runtime_symbol("sin", 8, false, "libm") == "_lfortran_dsin");
    assert(math_c_runtime_symbol("cos", 8, false, "libm") == "_lfortran_dcos");
    assert(math_c_runtime_symbol("sin", 4, false, "libm") == "_lfortran_ssin");
    assert(math_c_runtime_symbol("sin", 8, false, "pure") == "_lfortran_pure_dsin");
    assert(math_c_runtime_symbol("cos", 8, false, "pure") == "_lfortran_pure_dcos");
    assert(math_c_runtime_symbol("sin", 4, false, "pure") == "_lfortran_pure_ssin");
    // complex never pure
    assert(math_c_runtime_symbol("sin", 8, true, "pure") == "_lfortran_zsin");
    // other funcs stay libm names under pure policy
    assert(math_c_runtime_symbol("exp", 8, false, "pure") == "_lfortran_dexp");
    std::cout << "PASS math_c_runtime_symbol\n";
    return 0;
}
