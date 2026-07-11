#ifndef LIBASR_MATH_BACKEND_H
#define LIBASR_MATH_BACKEND_H

#include <string>

namespace LCompilers {

// Compile-time math backend policy (set from PassOptions during intrinsic replace).
// Values: "libm" (default) or "pure". Not a per-call switch.
inline std::string &math_backend_policy() {
    static thread_local std::string backend = "libm";
    return backend;
}

// Map elemental math name + kind to C runtime symbol for the active math backend.
// pure backend covers real sin/cos only; complex always uses host math library names.
inline std::string math_c_runtime_symbol(const std::string &name, int kind,
        bool is_complex, const std::string &backend = math_backend_policy()) {
    if (is_complex) {
        return (kind == 4) ? ("_lfortran_c" + name) : ("_lfortran_z" + name);
    }
    const bool pure_trig = (backend == "pure") && (name == "sin" || name == "cos");
    if (pure_trig) {
        return (kind == 4) ? ("_lfortran_pure_s" + name) : ("_lfortran_pure_d" + name);
    }
    return (kind == 4) ? ("_lfortran_s" + name) : ("_lfortran_d" + name);
}

} // namespace LCompilers

#endif // LIBASR_MATH_BACKEND_H
