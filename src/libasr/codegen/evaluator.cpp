#include <algorithm>
#include <cstdlib>
#include <functional>
#include <iostream>
#include <fstream>
#include <optional>
#include <set>
#include <utility>

#include <llvm/IR/LLVMContext.h>
#include <llvm/ADT/STLExtras.h>
#include <llvm/Analysis/AssumptionCache.h>
#include <llvm/Analysis/LoopInfo.h>
#include <llvm/Analysis/Passes.h>
#include <llvm/Analysis/ScalarEvolution.h>
#include <llvm/Analysis/ScalarEvolutionExpressions.h>
#include <llvm/Analysis/TargetTransformInfo.h>
#include <llvm/Analysis/TargetLibraryInfo.h>
#include <llvm/ExecutionEngine/ExecutionEngine.h>
#include <llvm/ExecutionEngine/GenericValue.h>
#include <llvm/ExecutionEngine/MCJIT.h>
#include <llvm/IR/Argument.h>
#include <llvm/IR/Attributes.h>
#include <llvm/IR/BasicBlock.h>
#include <llvm/IR/Constants.h>
#include <llvm/IR/DerivedTypes.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/MDBuilder.h>
#include <llvm/IR/Dominators.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/Intrinsics.h>
#include <llvm/IR/LegacyPassManager.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/Type.h>
#include <llvm/Support/Casting.h>
#include <llvm/Support/ManagedStatic.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/ADT/APFloat.h>
#include <llvm/ADT/SmallVector.h>
#include <llvm/ADT/STLExtras.h>
#include <llvm/ADT/StringMap.h>
#include <llvm/IR/Verifier.h>
#include <llvm/Transforms/Utils/Cloning.h>
#include <llvm/Transforms/Utils/LoopUtils.h>
#include <llvm/Pass.h>
#include <llvm/MC/MCSubtargetInfo.h>
#include <llvm/CodeGen/TargetSubtargetInfo.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Transforms/Scalar.h>
#include <llvm/Transforms/Utils.h>
#include <llvm/Transforms/Scalar/GVN.h>
#include <llvm/Transforms/InstCombine/InstCombine.h>
#include <llvm/Transforms/Scalar/InstSimplifyPass.h>
#include <llvm/Transforms/IPO.h>
#include <llvm/Transforms/IPO/AlwaysInliner.h>
#if LLVM_VERSION_MAJOR >= 9
#include <llvm/Transforms/Instrumentation/AddressSanitizer.h>
#include <llvm/Transforms/Instrumentation/ThreadSanitizer.h>
#endif
#include <llvm/ExecutionEngine/ObjectCache.h>
#include <llvm/Support/CommandLine.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/Path.h>
#include <llvm/AsmParser/Parser.h>
#include <llvm/Support/SourceMgr.h>
#include <llvm/ADT/StringRef.h>
#include <llvm/Target/TargetOptions.h>
#if LLVM_VERSION_MAJOR >= 14
#    include <llvm/MC/TargetRegistry.h>
#else
#    include <llvm/Support/TargetRegistry.h>
#endif
#if LLVM_VERSION_MAJOR >= 17
    // TODO: removed from LLVM 17
    #include <llvm/Passes/PassBuilder.h>
    #include <llvm/Transforms/Scalar/LICM.h>
    #include <llvm/Transforms/Scalar/LoopPassManager.h>
    #include <llvm/Transforms/Scalar/SimpleLoopUnswitch.h>
    #include <llvm/Transforms/Scalar/SROA.h>
    #include <llvm/Transforms/Scalar/SimplifyCFG.h>
#else
#    include <llvm/Transforms/IPO/PassManagerBuilder.h>
#endif

// `llvm/ADT/Triple.h` and `llvm/Support/Host.h` moved to `llvm/TargetParser/`
// in LLVM 17; only `Host.h` was left behind as a forwarding header.
#if LLVM_VERSION_MAJOR >= 17
#    include <llvm/TargetParser/Host.h>
#    include <llvm/TargetParser/Triple.h>
#else
#    include <llvm/ADT/Triple.h>
#    include <llvm/Support/Host.h>
#endif
#if LLVM_VERSION_MAJOR < 18
#    include <llvm/Transforms/Vectorize.h>
#endif
// The per-architecture target parsers moved to `llvm/TargetParser/` in LLVM 16.
#ifdef HAVE_TARGET_AARCH64
#    if LLVM_VERSION_MAJOR >= 16
#        include <llvm/TargetParser/AArch64TargetParser.h>
#    else
#        include <llvm/Support/AArch64TargetParser.h>
#    endif
#endif
// `X86TargetParser.h` was only introduced in LLVM 11, so `--march` cannot be
// resolved for x86 targets when building against an older LLVM.
#if defined(HAVE_TARGET_X86) && LLVM_VERSION_MAJOR >= 11
#    define LFORTRAN_HAVE_X86_TARGET_PARSER 1
#    if LLVM_VERSION_MAJOR >= 16
#        include <llvm/TargetParser/X86TargetParser.h>
#    else
#        include <llvm/Support/X86TargetParser.h>
#    endif
#endif

#include <libasr/codegen/KaleidoscopeJIT.h>
#include <libasr/codegen/evaluator.h>
#include <libasr/codegen/asr_to_llvm.h>
#include <libasr/codegen/llvm_reductions.h>
#include <libasr/codegen/llvm_rsqrt.h>
#include <libasr/codegen/asr_to_cpp.h>
#include <libasr/exception.h>
#include <libasr/asr.h>
#include <libasr/string_utils.h>

#ifdef HAVE_LFORTRAN_MLIR
#include <mlir/IR/BuiltinOps.h>
#include <mlir/Target/LLVMIR/Export.h>
#endif

// LLD wasm driver — included at global scope so LLD_HAS_DRIVER declares
// ::lld::wasm::link in the global lld namespace, not inside LCompilers.
#ifdef __EMSCRIPTEN__
#include <atomic>
#include <dlfcn.h>
#include <lld/Common/Driver.h>
LLD_HAS_DRIVER(wasm)
#endif

namespace LCompilers {

namespace {

void initialize_llvm_targets()
{
    llvm::InitializeNativeTarget();
    llvm::InitializeNativeTargetAsmPrinter();
    llvm::InitializeNativeTargetAsmParser();

#ifdef HAVE_TARGET_AARCH64
    LLVMInitializeAArch64Target();
    LLVMInitializeAArch64TargetInfo();
    LLVMInitializeAArch64TargetMC();
    LLVMInitializeAArch64AsmPrinter();
    LLVMInitializeAArch64AsmParser();
#endif
#ifdef HAVE_TARGET_X86
    LLVMInitializeX86Target();
    LLVMInitializeX86TargetInfo();
    LLVMInitializeX86TargetMC();
    LLVMInitializeX86AsmPrinter();
    LLVMInitializeX86AsmParser();
#endif
#ifdef HAVE_TARGET_WASM
    LLVMInitializeWebAssemblyTarget();
    LLVMInitializeWebAssemblyTargetInfo();
    LLVMInitializeWebAssemblyTargetMC();
    LLVMInitializeWebAssemblyAsmPrinter();
    LLVMInitializeWebAssemblyAsmParser();
#endif
}

const llvm::Target *get_llvm_target(const std::string &triple)
{
    std::string error;
#if LLVM_VERSION_MAJOR >= 21
    const llvm::Target *target = llvm::TargetRegistry::lookupTarget(
        llvm::Triple(triple), error);
#else
    const llvm::Target *target = llvm::TargetRegistry::lookupTarget(
        triple, error);
#endif
    if (!target) {
        throw LCompilersException(error);
    }
    return target;
}

bool is_host_target(const llvm::Triple &target)
{
    llvm::Triple host(llvm::Triple::normalize(
        llvm::sys::getDefaultTargetTriple()));
    if (target.getArch() != host.getArch()) {
        return false;
    }
    if (target.getOS() == host.getOS()
            && target.getEnvironment() == host.getEnvironment()) {
        return true;
    }
    // Darwin and MacOSX name one Apple platform. MACOSX_DEPLOYMENT_TARGET
    // rewrites the default darwin triple to macosxMAJOR.MINOR.MICRO, and
    // that host is still the machine we are compiling on.
    return target.isMacOSX() && host.isMacOSX()
        && target.getVendor() == host.getVendor()
        && target.getEnvironment() == host.getEnvironment();
}

std::string join_features(const std::vector<std::string> &features)
{
    std::string result;
    for (size_t i = 0; i < features.size(); i++) {
        if (i > 0) {
            result += ",";
        }
        result += features[i];
    }
    return result;
}

std::vector<std::string> get_detected_host_features()
{
    std::vector<std::string> features;
#if LLVM_VERSION_MAJOR >= 19
    auto host_features = llvm::sys::getHostCPUFeatures();
#else
    llvm::StringMap<bool, llvm::MallocAllocator> host_features;
    llvm::sys::getHostCPUFeatures(host_features);
#endif
    features.reserve(host_features.size());
    for (const auto &feature: host_features) {
        features.push_back(
            std::string(feature.getValue() ? "+" : "-")
            + feature.getKey().str());
    }
    std::sort(features.begin(), features.end());
    return features;
}

bool host_has_feature(const char *name)
{
#if LLVM_VERSION_MAJOR >= 19
    auto host_features = llvm::sys::getHostCPUFeatures();
#else
    llvm::StringMap<bool, llvm::MallocAllocator> host_features;
    llvm::sys::getHostCPUFeatures(host_features);
#endif
    return host_features.lookup(name);
}

#if defined(HAVE_TARGET_AARCH64) && LLVM_VERSION_MAJOR >= 18
std::vector<std::string> get_aarch64_extension_features(
    const llvm::AArch64::ExtensionSet &extensions)
{
#if LLVM_VERSION_MAJOR == 18
    std::vector<llvm::StringRef> parsed_features;
    extensions.toLLVMFeatureList(parsed_features);
    std::vector<std::string> features;
    features.reserve(parsed_features.size());
    for (llvm::StringRef feature: parsed_features) {
        features.push_back(feature.str());
    }
    return features;
#else
    std::vector<std::string> features;
    extensions.toLLVMFeatureList(features);
    return features;
#endif
}
#endif

std::vector<std::string> get_aarch64_cpu_features(
    const std::string &cpu, const llvm::Triple &triple)
{
#ifdef HAVE_TARGET_AARCH64
#if LLVM_VERSION_MAJOR >= 18
    std::optional<llvm::AArch64::CpuInfo> cpu_info
        = llvm::AArch64::parseCpu(cpu);
    if (!cpu_info) {
        throw LCompilersException("unsupported cpu '" + cpu
            + "' for target '" + triple.str() + "'");
    }
    llvm::AArch64::ExtensionSet extensions;
    extensions.addCPUDefaults(*cpu_info);
    return get_aarch64_extension_features(extensions);
#else
#if LLVM_VERSION_MAJOR == 17
    std::optional<llvm::AArch64::CpuInfo> cpu_info
        = llvm::AArch64::parseCpu(cpu);
    if (!cpu_info) {
        throw LCompilersException("unsupported cpu '" + cpu
            + "' for target '" + triple.str() + "'");
    }
    std::vector<llvm::StringRef> parsed_features = {
        cpu_info->Arch.ArchFeature
    };
    llvm::AArch64::getExtensionFeatures(
        cpu_info->getImpliedExtensions(), parsed_features);
#elif LLVM_VERSION_MAJOR == 16
    const llvm::AArch64::CpuInfo &cpu_info
        = llvm::AArch64::parseCpu(cpu);
    if (cpu_info.Name == "invalid") {
        throw LCompilersException("unsupported cpu '" + cpu
            + "' for target '" + triple.str() + "'");
    }
    std::vector<llvm::StringRef> parsed_features = {
        cpu_info.Arch.ArchFeature
    };
    llvm::AArch64::getExtensionFeatures(
        llvm::AArch64::getDefaultExtensions(cpu, cpu_info.Arch),
        parsed_features);
#else
    llvm::AArch64::ArchKind arch = llvm::AArch64::parseCPUArch(cpu);
    if (arch == llvm::AArch64::ArchKind::INVALID) {
        throw LCompilersException("unsupported cpu '" + cpu
            + "' for target '" + triple.str() + "'");
    }
    std::vector<llvm::StringRef> parsed_features;
    llvm::AArch64::getArchFeatures(arch, parsed_features);
    llvm::AArch64::getExtensionFeatures(
        llvm::AArch64::getDefaultExtensions(cpu, arch), parsed_features);
#endif
    std::vector<std::string> features;
    features.reserve(parsed_features.size());
    for (llvm::StringRef feature: parsed_features) {
        features.push_back(feature.str());
    }
    return features;
#endif
#else
    (void)cpu;
    throw LCompilersException("cpu feature detection is not supported for target '"
        + triple.str() + "' by this LFortran build");
#endif
}

std::string get_host_cpu(const std::string &option,
    const LLVMTargetConfig &config)
{
    if (!config.host_target) {
        throw LCompilersException("`" + option
            + "=native` is only supported when targeting the host");
    }
    std::string cpu = llvm::sys::getHostCPUName().str();
    if (cpu.empty()) {
        throw LCompilersException("could not detect the host cpu for `"
            + option + "=native`");
    }
    return cpu;
}

bool is_valid_cpu(const llvm::Target &target, const llvm::Triple &triple,
    const std::string &cpu)
{
    if (cpu == "generic") {
        return true;
    }
    std::unique_ptr<llvm::MCSubtargetInfo> subtarget(
#if LLVM_VERSION_MAJOR >= 22
        target.createMCSubtargetInfo(triple, "generic", "")
#else
        target.createMCSubtargetInfo(triple.str(), "generic", "")
#endif
    );
    return subtarget && subtarget->isCPUStringValid(cpu);
}

void validate_cpu(const llvm::Target &target, const llvm::Triple &triple,
    const std::string &cpu, const std::string &option)
{
    if (!is_valid_cpu(target, triple, cpu)) {
        throw LCompilersException("unsupported cpu '" + cpu
            + "' for target '" + triple.str() + "' in `" + option + "`");
    }
}

// Resolve `native` for `--mcpu` / `--mtune`. LLVM reports "generic" when it
// cannot identify the host, and may name a CPU that this LLVM's code generator
// does not accept; falling back to "generic" keeps `--fast` and
// `<option>=native` working on such hosts instead of failing the compilation.
std::string resolve_native_cpu(const llvm::Target &target,
    const llvm::Triple &triple, const std::string &option,
    const LLVMTargetConfig &config)
{
    std::string cpu = get_host_cpu(option, config);
    if (!is_valid_cpu(target, triple, cpu)) {
        return "generic";
    }
    if (cpu == "generic") {
        // LLVM reports "generic" for CPUs it does not recognize. Its generic
        // cost model prefers 512-bit vectors, but known models with the same
        // instruction set use 256-bit vectors, which is faster for small
        // loops. Keep the detected features and only switch the CPU model.
        if (host_has_feature("avx512f")) {
            return "skylake-avx512";
        } else if (host_has_feature("avx2")) {
            return "haswell";
        }
    }
    return cpu;
}

std::vector<std::string> get_aarch64_arch_features(
    const std::string &march, const llvm::Triple &triple)
{
#ifdef HAVE_TARGET_AARCH64
    llvm::SmallVector<llvm::StringRef, 8> parts;
    llvm::StringRef(march).split(parts, '+', -1, false);
    if (parts.empty()) {
        throw LCompilersException("missing architecture in `--march`");
    }

#if LLVM_VERSION_MAJOR >= 18
    const llvm::AArch64::ArchInfo *arch
        = llvm::AArch64::parseArch(parts[0]);
    if (!arch) {
        throw LCompilersException("unsupported architecture '" + march
            + "' for target '" + triple.str()
            + "'; use `--mcpu` for processor names");
    }
    llvm::AArch64::ExtensionSet extensions;
    extensions.addArchDefaults(*arch);
    for (size_t i = 1; i < parts.size(); i++) {
        if (!extensions.parseModifier(parts[i])) {
            throw LCompilersException("unsupported architecture extension '"
                + parts[i].str() + "' in `--march=" + march + "`");
        }
    }
    return get_aarch64_extension_features(extensions);
#else
#if LLVM_VERSION_MAJOR == 17
    std::optional<llvm::AArch64::ArchInfo> arch_info
        = llvm::AArch64::parseArch(parts[0]);
    if (!arch_info) {
        throw LCompilersException("unsupported architecture '" + march
            + "' for target '" + triple.str()
            + "'; use `--mcpu` for processor names");
    }
    std::vector<llvm::StringRef> parsed_features = {
        arch_info->ArchFeature
    };
    llvm::AArch64::getExtensionFeatures(
        arch_info->DefaultExts, parsed_features);
#elif LLVM_VERSION_MAJOR == 16
    const llvm::AArch64::ArchInfo &arch
        = llvm::AArch64::parseArch(parts[0]);
    if (arch.Name == "invalid") {
        throw LCompilersException("unsupported architecture '" + march
            + "' for target '" + triple.str()
            + "'; use `--mcpu` for processor names");
    }
    std::vector<llvm::StringRef> parsed_features = {
        arch.ArchFeature
    };
    llvm::AArch64::getExtensionFeatures(
        llvm::AArch64::getDefaultExtensions("", arch), parsed_features);
#else
    llvm::AArch64::ArchKind arch = llvm::AArch64::parseArch(parts[0]);
    if (arch == llvm::AArch64::ArchKind::INVALID) {
        throw LCompilersException("unsupported architecture '" + march
            + "' for target '" + triple.str()
            + "'; use `--mcpu` for processor names");
    }
    std::vector<llvm::StringRef> parsed_features;
    llvm::AArch64::getArchFeatures(arch, parsed_features);
    llvm::AArch64::getExtensionFeatures(
        llvm::AArch64::getDefaultExtensions("", arch), parsed_features);
#endif
    std::vector<std::string> features;
    features.reserve(parsed_features.size() + parts.size() - 1);
    for (llvm::StringRef feature: parsed_features) {
        features.push_back(feature.str());
    }
    for (size_t i = 1; i < parts.size(); i++) {
        llvm::StringRef extension = parts[i];
        bool disable = extension.consume_front("no");
        llvm::StringRef feature
            = llvm::AArch64::getArchExtFeature(extension);
        if (feature.empty()) {
            throw LCompilersException("unsupported architecture extension '"
                + parts[i].str() + "' in `--march=" + march + "`");
        }
        std::string feature_string = feature.str();
        if (disable) {
            if (!feature_string.empty() && feature_string[0] == '+') {
                feature_string[0] = '-';
            } else {
                feature_string = "-" + feature_string;
            }
        }
        features.push_back(feature_string);
    }
    return features;
#endif
#else
    (void)march;
    throw LCompilersException("`--march` is not supported for target '"
        + triple.str() + "' by this LFortran build");
#endif
}

std::vector<std::string> get_x86_arch_features(
    const std::string &march, const llvm::Triple &triple)
{
#ifdef LFORTRAN_HAVE_X86_TARGET_PARSER
    bool only_64_bit = triple.getArch() == llvm::Triple::x86_64;
    if (llvm::X86::parseArchX86(march, only_64_bit)
            == llvm::X86::CK_None) {
        throw LCompilersException("unsupported architecture '" + march
            + "' for target '" + triple.str() + "'");
    }
    llvm::SmallVector<llvm::StringRef, 32> parsed_features;
#if LLVM_VERSION_MAJOR >= 22
    llvm::X86::getFeaturesForCPU(march, parsed_features, true);
#else
    llvm::X86::getFeaturesForCPU(march, parsed_features);
#endif
    std::vector<std::string> features;
    features.reserve(parsed_features.size());
    for (llvm::StringRef feature: parsed_features) {
#if LLVM_VERSION_MAJOR >= 22
        features.push_back(feature.str());
#else
        features.push_back("+" + feature.str());
#endif
    }
    return features;
#else
    (void)march;
    throw LCompilersException("`--march` is not supported for target '"
        + triple.str() + "' by this LFortran build");
#endif
}

std::vector<std::string> get_arch_features(
    const std::string &march, const llvm::Triple &triple,
    const LLVMTargetConfig &config)
{
    if (march == "native") {
        std::string host_cpu = get_host_cpu("--march", config);
        std::vector<std::string> features;
        // LLVM reports "generic" when it cannot identify the host, and a CPU
        // newer than this LLVM release is not in its architecture tables
        // either. Neither is a user error, so treat the table lookup as a
        // best-effort refinement: the detected feature set below is what
        // `native` actually promises.
        if (host_cpu != "generic") {
            try {
                if (triple.isAArch64()) {
                    features = get_aarch64_cpu_features(host_cpu, triple);
                } else if (triple.getArch() == llvm::Triple::x86
                        || triple.getArch() == llvm::Triple::x86_64) {
                    features = get_x86_arch_features(host_cpu, triple);
                }
            } catch (const LCompilersException &) {
                features.clear();
            }
        }
        std::vector<std::string> detected_features
            = get_detected_host_features();
        features.insert(features.end(), detected_features.begin(),
            detected_features.end());
        return features;
    }
    if (triple.isAArch64()) {
        return get_aarch64_arch_features(march, triple);
    }
    if (triple.getArch() == llvm::Triple::x86
            || triple.getArch() == llvm::Triple::x86_64) {
        return get_x86_arch_features(march, triple);
    }
    throw LCompilersException("`--march` is not supported for target '"
        + triple.str() + "'");
}

#if LLVM_VERSION_MAJOR >= 18
using CodeGenOptLevel = llvm::CodeGenOptLevel;
#else
using CodeGenOptLevel = llvm::CodeGenOpt::Level;
#endif

bool is_wasm_triple(const llvm::Triple &triple)
{
    return triple.getArch() == llvm::Triple::wasm32
        || triple.getArch() == llvm::Triple::wasm64;
}

// Machine code generation follows clang and flang: the default mode is -O0,
// which selects the -O0 instruction selector and the fast register allocator,
// and `--fast` is -O3. The default mode runs no IR optimizations.
CodeGenOptLevel codegen_opt_level(const LLVMTargetConfig &config)
{
    if (config.fast) {
        return CodeGenOptLevel::Aggressive;
    }
    // At -O0 the WebAssembly backend skips register stackification and
    // coloring, so every virtual register becomes a separate local, and large
    // functions exceed the 50000 locals per function that engines accept.
    if (is_wasm_triple(llvm::Triple(config.triple))) {
        return CodeGenOptLevel::Default;
    }
    return CodeGenOptLevel::None;
}

std::unique_ptr<llvm::TargetMachine> create_target_machine(
    const LLVMTargetConfig &config)
{
    const llvm::Target *target = get_llvm_target(config.triple);
    llvm::TargetOptions options;
    // The IR of `--fast` already allows contraction (`fast` flags), but the
    // AArch64 backend of LLVM 11 only fuses with this option.
    if (config.fast_math) {
        options.AllowFPOpFusion = llvm::FPOpFusion::Fast;
    }
    llvm::Triple triple(config.triple);
    // ELF startup code runs .init_array. LLD leaves .ctors as its own section,
    // so constructors there never run. Clang emits .init_array on ELF.
    if (triple.isOSBinFormatELF()) {
        options.UseInitArray = true;
    }
    // WebAssembly objects are linked into static executables (wasm-ld for
    // WASI, emcc for Emscripten), which do not need position independent
    // code; clang also defaults to the static model there. In the PIC model
    // the WebAssembly backend lowers a call through a pointer that was just
    // loaded with a function's address as a direct `call` with a GOT
    // relocation, which produces an invalid module.
    bool is_wasm = is_wasm_triple(triple);
    RM_OPTIONAL_TYPE<llvm::Reloc::Model> relocation_model
        = is_wasm ? llvm::Reloc::Model::Static : llvm::Reloc::Model::PIC_;
    RM_OPTIONAL_TYPE<llvm::CodeModel::Model> code_model;
    llvm::TargetMachine *machine = target->createTargetMachine(
#if LLVM_VERSION_MAJOR >= 21
        llvm::Triple(config.triple),
#else
        config.triple,
#endif
        config.cpu, config.features, options, relocation_model, code_model,
        codegen_opt_level(config));
    if (!machine) {
        throw LCompilersException("could not create target machine for '"
            + config.triple + "'");
    }
    // At -O0 the AArch64 backend selects GlobalISel (clang uses it too), whose
    // localizer scans a basic block linearly for each value it moves, so code
    // generation time is quadratic in the size of large blocks. Select
    // FastISel instead, as on x86-64; it falls back to SelectionDAG for what
    // it does not handle.
    if (machine->getOptLevel() == CodeGenOptLevel::None
            && triple.isAArch64()) {
        machine->setGlobalISel(false);
    }
    return std::unique_ptr<llvm::TargetMachine>(machine);
}

LLVMTargetConfig resolve_target_only(const std::string &target)
{
    CompilerOptions compiler_options;
    compiler_options.target = target;
    return resolve_llvm_target_config(compiler_options);
}

} // namespace

void LLVMTargetConfig::apply_target_attributes(llvm::Module &module) const
{
    for (llvm::Function &function: module) {
        if (function.isDeclaration()) {
            continue;
        }
        if (emit_cpu_attribute) {
            function.addFnAttr("target-cpu", cpu);
        }
        if (!features.empty()) {
            function.addFnAttr("target-features", features);
        }
        // 512-bit vectors lower the core frequency on Intel AVX-512 CPUs.
        // clang's default for icelake is a 256-bit preference, and gfortran
        // -march=native keeps the same class of loop in ymm.
        if (prefer_vector_width != 0) {
            function.addFnAttr("prefer-vector-width",
                std::to_string(prefer_vector_width));
        }
        if (!tune_cpu.empty()) {
            function.addFnAttr("tune-cpu", tune_cpu);
        }
    }
}

namespace {

// "15", "15.7" and "15.7.1" are accepted. Missing components are 0.
bool parse_macos_version(const char *text, unsigned &major, unsigned &minor,
        unsigned &micro) {
    major = 0;
    minor = 0;
    micro = 0;
    if (text == nullptr || *text == '\0') {
        return false;
    }
    char *end = nullptr;
    unsigned long value = std::strtoul(text, &end, 10);
    if (end == text) {
        return false;
    }
    major = static_cast<unsigned>(value);
    if (*end == '\0') {
        return true;
    }
    if (*end != '.') {
        return false;
    }
    text = end + 1;
    value = std::strtoul(text, &end, 10);
    if (end == text) {
        return false;
    }
    minor = static_cast<unsigned>(value);
    if (*end == '\0') {
        return true;
    }
    if (*end != '.') {
        return false;
    }
    text = end + 1;
    value = std::strtoul(text, &end, 10);
    if (end == text || *end != '\0') {
        return false;
    }
    micro = static_cast<unsigned>(value);
    return true;
}

std::string format_macos_version(unsigned major, unsigned minor, unsigned micro) {
    return std::to_string(major) + "." + std::to_string(minor) + "."
        + std::to_string(micro);
}

bool macos_version_numbers(const llvm::Triple &triple, unsigned &major,
        unsigned &minor, unsigned &micro) {
#if LLVM_VERSION_MAJOR >= 15
    llvm::VersionTuple version;
    if (!triple.getMacOSXVersion(version)) {
        return false;
    }
    major = version.getMajor();
    minor = version.getMinor() ? *version.getMinor() : 0;
    micro = version.getSubminor() ? *version.getSubminor() : 0;
    return true;
#else
    return triple.getMacOSXVersion(major, minor, micro);
#endif
}

} // namespace

std::string apply_macos_deployment_target(const std::string &triple) {
    const char *deployment = std::getenv("MACOSX_DEPLOYMENT_TARGET");
    unsigned major = 0;
    unsigned minor = 0;
    unsigned micro = 0;
    if (!parse_macos_version(deployment, major, minor, micro)) {
        return triple;
    }
    llvm::Triple rewritten(triple);
    if (!rewritten.isMacOSX()) {
        return triple;
    }
    rewritten.setOSName("macosx" + format_macos_version(major, minor, micro));
    return rewritten.str();
}

std::string macos_platform_version(const std::string &triple) {
    llvm::Triple parsed(triple);
    if (!parsed.isMacOSX()) {
        return "";
    }
    unsigned major = 0;
    unsigned minor = 0;
    unsigned micro = 0;
    if (!macos_version_numbers(parsed, major, minor, micro)) {
        return "";
    }
    return format_macos_version(major, minor, micro);
}

// CPUs whose LLVM model enables AVX-512. The model also requests a 256-bit
// preferred width, but an explicit target-features string does not carry
// that bit, so the driver selects it itself.
static bool cpu_selects_avx512(const std::string &cpu) {
    static const char *names[] = {
        "knl", "knm", "skylake-avx512", "skx", "cascadelake", "cooperlake",
        "cannonlake", "icelake-client", "icelake-server", "tigerlake",
        "sapphirerapids", "graniterapids", "znver4",
    };
    for (const char *name : names) {
        if (cpu == name) {
            return true;
        }
    }
    return false;
}

static unsigned resolve_prefer_vector_width(const CompilerOptions &compiler_options,
        const LLVMTargetConfig &config) {
    const std::string &requested = compiler_options.prefer_vector_width;
    if (!requested.empty()) {
        if (requested == "128" || requested == "256" || requested == "512") {
            return static_cast<unsigned>(std::stoul(requested));
        }
        throw LCompilersException(
            "prefer-vector-width must be 128, 256, or 512");
    }
    llvm::Triple triple(config.triple);
    bool avx512 = config.features.find("+avx512f") != std::string::npos
        || cpu_selects_avx512(config.cpu);
    if (config.fast && triple.getArch() == llvm::Triple::x86_64 && avx512) {
        return 256;
    }
    return 0;
}

LLVMTargetConfig resolve_llvm_target_config(
    const CompilerOptions &compiler_options)
{
    initialize_llvm_targets();

    LLVMTargetConfig config;
    config.fast = compiler_options.po.fast;
    config.fast_math = compiler_options.po.fast
        && !compiler_options.po.no_fast_math;
    config.triple = compiler_options.target.empty()
        ? apply_macos_deployment_target(llvm::sys::getDefaultTargetTriple())
        : llvm::Triple::normalize(compiler_options.target);
    llvm::Triple triple(config.triple);
    config.host_target = is_host_target(triple);
    const llvm::Target *target = get_llvm_target(config.triple);

    std::string march = compiler_options.march;
    std::string mcpu = compiler_options.mcpu;
    std::string mtune = compiler_options.mtune;
    if (config.fast && compiler_options.target.empty()
            && march.empty() && mcpu.empty() && mtune.empty()) {
        mcpu = "native";
    }

    std::vector<std::string> features;
    if (!march.empty()) {
        features = get_arch_features(march, triple, config);
    }

    std::string resolved_cpu;
    if (!mcpu.empty()) {
        resolved_cpu = mcpu == "native"
            ? resolve_native_cpu(*target, triple, "--mcpu", config)
            : mcpu;
        validate_cpu(*target, triple, resolved_cpu, "--mcpu");
    }

    if (!march.empty()) {
        config.cpu = "generic";
        if (!resolved_cpu.empty()) {
            config.tune_cpu = resolved_cpu;
        }
    } else if (!resolved_cpu.empty()) {
        config.cpu = resolved_cpu;
        config.emit_cpu_attribute = true;
        if (mcpu == "native") {
            features = get_detected_host_features();
        }
    }

    if (!mtune.empty()) {
        config.tune_cpu = mtune == "native"
            ? resolve_native_cpu(*target, triple, "--mtune", config)
            : mtune;
        validate_cpu(*target, triple, config.tune_cpu, "--mtune");
    }

#if LLVM_VERSION_MAJOR < 10
    // The x86 backends of LLVM 7, 8 and 9 add the fp128 register class (XMM)
    // to an x86-64 subtarget only when it has MMX (X86ISelLowering.cpp:
    // `is64Bit() && hasMMX()`). Without it, fp128 arguments are expanded into
    // integer pairs, so real(16) arithmetic and comparisons call the libgcc
    // helpers (e.g. __subtf3, __lttf2) with fp128 in general purpose
    // registers, while libgcc and the psABI expect SSE registers, and every
    // real(16) result is wrong. The "generic" CPU that we use by default has
    // only x87 plus the 64-bit baseline SSE2, but no MMX. Target the x86-64
    // baseline, which clang uses by default and which includes MMX. LLVM 10
    // removed the MMX condition.
    if (march.empty() && resolved_cpu.empty()
            && triple.getArch() == llvm::Triple::x86_64) {
        config.cpu = "x86-64";
    }
#endif
    config.features = join_features(features);
    config.prefer_vector_width = resolve_prefer_vector_width(
        compiler_options, config);
    std::unique_ptr<llvm::TargetMachine> machine
        = create_target_machine(config);
    config.data_layout
        = machine->createDataLayout().getStringRepresentation();
    return config;
}

// Extracts the integer from APInt.
// APInt does not seem to have this functionality, so we implement it here.
uint64_t APInt_getint(const llvm::APInt &i) {
    // The APInt::isSingleWord() is private, but we can emulate it:
    bool isSingleWord = !i.needsCleanup();
    if (isSingleWord) {
        return *i.getRawData();
    } else {
        throw std::runtime_error("APInt too large to fit uint64_t");
    }
}

LLVMModule::LLVMModule(std::unique_ptr<llvm::Module> m)
{
    m_m = std::move(m);
}

LLVMModule::~LLVMModule() = default;

std::string LLVMModule::str()
{
    return LLVMEvaluator::module_to_string(*m_m);
}

llvm::Function *LLVMModule::get_function(const std::string &fn_name) {
    llvm::Module *m = m_m.get();
    return m->getFunction(fn_name);
}

llvm::GlobalVariable *LLVMModule::get_global(const std::string &global_name) {
    llvm::Module *m = m_m.get();
    return m->getNamedGlobal(global_name);
}

std::string LLVMModule::get_return_type(const std::string &fn_name)
{
    llvm::Module *m = m_m.get();
    llvm::Function *fn = m->getFunction(fn_name);
    if (!fn) {
        return "none";
    }
    llvm::Type *type = fn->getReturnType();
    if (type->isFloatTy()) {
        return "real4";
    } else if (type->isDoubleTy()) {
        return "real8";
    } else if (type->isIntegerTy(1)) {
        return "logical";
    } else if (type->isIntegerTy(32)) {
        return "integer4";
    } else if (type->isIntegerTy(64)) {
        return "integer8";
    } else if (type->isStructTy()) {
        llvm::StructType *st = llvm::cast<llvm::StructType>(type);
        if (st->hasName()) {
            if (startswith(std::string(st->getName()), "complex_4")) {
                return "complex4";
            } else if (startswith(std::string(st->getName()), "complex_8")) {
                return "complex8";
            } else {
                throw LCompilersException("LLVMModule::get_return_type(): StructType return type `" + std::string(st->getName()) + "` not supported");
            }
        } else {
            throw LCompilersException("LLVMModule::get_return_type(): Noname struct return type not supported");
        }
    } else if (type->isVectorTy()) {
        // Used for passing complex_4 on some platforms
        return "complex4";
    } else if (type->isVoidTy()) {
        return "void";
    } else {
        throw LCompilersException("LLVMModule::get_return_type(): Return type not supported");
    }
}

#ifdef HAVE_LFORTRAN_MLIR
MLIRModule::MLIRModule(std::unique_ptr<mlir::ModuleOp> m,
        std::unique_ptr<mlir::MLIRContext> ctx) {
    mlir_m = std::move(m);
    mlir_ctx = std::move(ctx);
    llvm_ctx = std::make_unique<llvm::LLVMContext>();
}

MLIRModule::~MLIRModule() {
    llvm_m.reset();
    llvm_ctx.reset();
};

std::string MLIRModule::mlir_str() {
    std::string mlir_str;
    llvm::raw_string_ostream raw_os(mlir_str);
    mlir_m->print(raw_os);
    return mlir_str;
}

std::string MLIRModule::llvm_str() {
    std::string mlir_str;
    llvm::raw_string_ostream raw_os(mlir_str);
    llvm_m->print(raw_os, nullptr);
    return mlir_str;
}

void MLIRModule::mlir_to_llvm(llvm::LLVMContext &ctx) {
    std::unique_ptr<llvm::Module> llvmModule = mlir::translateModuleToLLVMIR(
        *mlir_m, ctx);
    if (llvmModule) {
        llvm_m = std::move(llvmModule);
    } else {
        throw LCompilersException("Failed to generate LLVM IR");
    }
}
#endif

extern "C" {

float _lfortran_stan(float x);

}

LLVMEvaluator::LLVMEvaluator(const std::string &target)
    : LLVMEvaluator(resolve_target_only(target))
{
}

LLVMEvaluator::LLVMEvaluator(const CompilerOptions &compiler_options)
    : LLVMEvaluator(resolve_llvm_target_config(compiler_options))
{
}

LLVMEvaluator::LLVMEvaluator(LLVMTargetConfig target_config_)
    : target_config(std::move(target_config_))
{
    context = std::make_unique<llvm::LLVMContext>();
    TM = create_target_machine(target_config);

    // For some reason the JIT requires a different TargetMachine
    jit = cantFail(llvm::orc::KaleidoscopeJIT::Create(
        codegen_opt_level(target_config)));

    _lfortran_stan(0.5);
}

LLVMEvaluator::~LLVMEvaluator()
{
    jit.reset();
    context.reset();
}

void LLVMEvaluator::configure_module(llvm::Module &module) const
{
#if LLVM_VERSION_MAJOR >= 21
    module.setTargetTriple(llvm::Triple(target_config.triple));
#else
    module.setTargetTriple(target_config.triple);
#endif
    module.setDataLayout(target_config.data_layout);
    target_config.apply_target_attributes(module);
}

std::unique_ptr<llvm::Module> LLVMEvaluator::parse_module(const std::string &source, const std::string &filename="")
{
    llvm::SMDiagnostic err;
    std::unique_ptr<llvm::Module> module;
    if (!filename.empty()) {
        module = llvm::parseAssemblyFile(filename, err, *context);
    } else {
        module = llvm::parseAssemblyString(source, err, *context);
    }
    if (!module) {
        err.print("", llvm::errs());
        throw LCompilersException("parse_module(): Invalid LLVM IR");
    }
    bool v = llvm::verifyModule(*module);
    if (v) {
        throw LCompilersException("parse_module(): module failed verification.");
    };
    configure_module(*module);
    return module;
}

std::unique_ptr<LLVMModule> LLVMEvaluator::parse_module2(const std::string &source, const std::string &filename="") {
    return std::make_unique<LLVMModule>(parse_module(source, filename));
}

void LLVMEvaluator::add_module(const std::string &source) {
    std::unique_ptr<llvm::Module> module = parse_module(source);
    // TODO: apply LLVM optimizations here
    // Uncomment the below code to print the module to stdout:
    /*
    std::cout << "---------------------------------------------" << std::endl;
    std::cout << "LLVM Module IR:" << std::endl;
    std::cout << module_to_string(*module);
    std::cout << "---------------------------------------------" << std::endl;
    */
    add_module(std::move(module));
}

void LLVMEvaluator::add_module(std::unique_ptr<llvm::Module> mod) {
    // These are already set in parse_module(), but we set it here again for
    // cases when the Module was constructed directly, not via parse_module().
    configure_module(*mod);
    mod->setDataLayout(jit->getDataLayout());
    llvm::Error err = jit->addModule(std::move(mod), context);
    if (err) {
        llvm::SmallVector<char, 128> buf;
        llvm::raw_svector_ostream dest(buf);
        llvm::logAllUnhandledErrors(std::move(err), dest, "");
        std::string msg = std::string(dest.str().data(), dest.str().size());
        if (msg[msg.size()-1] == '\n') msg = msg.substr(0, msg.size()-1);
        throw LCompilersException("addModule() returned an error: " + msg);
    }

}

void LLVMEvaluator::add_module(std::unique_ptr<LLVMModule> m) {
    add_module(std::move(m->m_m));
}

intptr_t LLVMEvaluator::get_symbol_address(const std::string &name) {
#if LLVM_VERSION_MAJOR < 8
    // LLVM 7: Use findSymbol which returns JITSymbol
    llvm::JITSymbol s = jit->findSymbol(name);
    if (!s) {
        throw LCompilersException("findSymbol() failed to find the symbol '" + name + "'");
    }
    auto addr = s.getAddress();
    if (!addr) {
        llvm::Error e = addr.takeError();
        llvm::SmallVector<char, 128> buf;
        llvm::raw_svector_ostream dest(buf);
        llvm::logAllUnhandledErrors(std::move(e), dest, "");
        std::string msg = std::string(dest.str().data(), dest.str().size());
        if (msg[msg.size()-1] == '\n') msg = msg.substr(0, msg.size()-1);
        throw LCompilersException("getAddress() failed for symbol '"
            + name + "', error: " + msg);
    }
    return (intptr_t)addr.get();
#else
#if LLVM_VERSION_MAJOR < 17
    llvm::Expected<llvm::JITEvaluatedSymbol>
#else
    llvm::Expected<llvm::orc::ExecutorSymbolDef>
#endif
        s = jit->lookup(name);
    if (!s) {
        llvm::Error e = s.takeError();
        llvm::SmallVector<char, 128> buf;
        llvm::raw_svector_ostream dest(buf);
        llvm::logAllUnhandledErrors(std::move(e), dest, "");
        std::string msg = std::string(dest.str().data(), dest.str().size());
        if (msg[msg.size()-1] == '\n') msg = msg.substr(0, msg.size()-1);
        throw LCompilersException("lookup() failed to find the symbol '"
            + name + "', error: " + msg);
    }
#if LLVM_VERSION_MAJOR < 17
    llvm::Expected<uint64_t> addr0 = s->getAddress();
#else
    llvm::Expected<uint64_t> addr0 = s->getAddress().getValue();
#endif
    if (!addr0) {
        llvm::Error e = addr0.takeError();
        llvm::SmallVector<char, 128> buf;
        llvm::raw_svector_ostream dest(buf);
        llvm::logAllUnhandledErrors(std::move(e), dest, "");
        std::string msg = std::string(dest.str().data(), dest.str().size());
        if (msg[msg.size()-1] == '\n') msg = msg.substr(0, msg.size()-1);
        throw LCompilersException("JITSymbol::getAddress() returned an error: " + msg);
    }
    return (intptr_t)cantFail(std::move(addr0));
#endif
}

void write_file(const std::string &filename, const std::string &contents)
{
    std::ofstream out;
    out.open(filename);
    out << contents << std::endl;
}

std::string LLVMEvaluator::get_asm(llvm::Module &m)
{
    configure_module(m);
    llvm::legacy::PassManager pass;
#if LLVM_VERSION_MAJOR < 10
    llvm::LLVMTargetMachine::CodeGenFileType ft = llvm::LLVMTargetMachine::CGFT_AssemblyFile;
#elif LLVM_VERSION_MAJOR < 18
    llvm::CodeGenFileType ft = llvm::CGFT_AssemblyFile;
#else
    llvm::CodeGenFileType ft = llvm::CodeGenFileType::AssemblyFile;
#endif
    llvm::SmallVector<char, 128> buf;
    llvm::raw_svector_ostream dest(buf);
    if (TM->addPassesToEmitFile(pass, dest, nullptr, ft)) {
        throw std::runtime_error("TargetMachine can't emit a file of this type");
    }
    pass.run(m);
    return std::string(dest.str().data(), dest.str().size());
}

void LLVMEvaluator::save_asm_file(llvm::Module &m, const std::string &filename)
{
    write_file(filename, get_asm(m));
}

void LLVMEvaluator::save_object_file(llvm::Module &m, const std::string &filename) {
    configure_module(m);

    llvm::legacy::PassManager pass;
#if LLVM_VERSION_MAJOR < 10
    llvm::LLVMTargetMachine::CodeGenFileType ft = llvm::LLVMTargetMachine::CGFT_ObjectFile;
#elif LLVM_VERSION_MAJOR < 18
    llvm::CodeGenFileType ft = llvm::CGFT_ObjectFile;
#else
    llvm::CodeGenFileType ft = llvm::CodeGenFileType::ObjectFile;
#endif
    std::error_code EC;
    llvm::raw_fd_ostream dest(filename, EC, llvm::sys::fs::OF_None);
    if (EC) {
        throw std::runtime_error("raw_fd_ostream failed");
    }
    if (TM->addPassesToEmitFile(pass, dest, nullptr, ft)) {
        throw std::runtime_error("TargetMachine can't emit a file of this type");
    }
    pass.run(m);
    dest.flush();
}

void LLVMEvaluator::create_empty_object_file(const std::string &filename) {
    std::string source;
    std::unique_ptr<llvm::Module> module = parse_module(source);
    save_object_file(*module, filename);
}

#if LLVM_VERSION_MAJOR < 9
// IndVarSimplify in LLVM 7 and 8 can mark the increment of a loop counter
// that starts at -1 (a DO loop starting at 0) as `nuw`. Unrolling an inner
// loop by the upper bound of its trip count then trusts that flag, assumes at
// least two iterations and drops the first exit test, so a one-trip loop runs
// twice. LLVM 9 fixed this. X86 enables upper-bound unrolling for CPUs with a
// loop buffer, so the miscompile depends on the host CPU under `--fast`.
static void disable_upper_bound_unrolling() {
    llvm::StringMap<llvm::cl::Option*> &options
        = llvm::cl::getRegisteredOptions();
    auto option = options.find("unroll-max-upperbound");
    // The option may occur only once per process; opt() runs for every file
    // and REPL cell.
    if (option != options.end() && option->second->getNumOccurrences() == 0) {
        option->second->addOccurrence(0, "unroll-max-upperbound", "0");
    }
}
#endif

// glibc libmvec names for exp. Width is the lane count. A width with no
// entry here is left as the LLVM intrinsic.
// Only double. The float entry points differ from scalar expf in the last
// bit, and elemental tests compare those results exactly.
static const char *libmvec_exp_name(bool is_float, unsigned width, bool avx2) {
    if (is_float) {
        return nullptr;
    }
    switch (width) {
        case 2: return "_ZGVbN2v_exp";
        // The AVX entry point does not use FMA. On a target that has AVX2,
        // glibc's AVX2 entry is the one gfortran calls for a 4-wide exp.
        case 4: return avx2 ? "_ZGVdN4v_exp" : "_ZGVcN4v_exp";
        case 8: return "_ZGVeN8v_exp";
        default: return nullptr;
    }
}

static void sink_call_to_its_users(llvm::Module &m, const char *name);

static void eliminate_unused_alloc_pairs(llvm::Module &m) {
    llvm::Function *malloc_fn = m.getFunction("_lfortran_malloc_alloc");
    llvm::Function *free_fn = m.getFunction("_lfortran_free_alloc");
    if (malloc_fn == nullptr) {
        return;
    }
    std::vector<llvm::CallInst *> dead;
    for (llvm::User *user : malloc_fn->users()) {
        auto *call = llvm::dyn_cast<llvm::CallInst>(user);
        if (call == nullptr || call->getCalledFunction() != malloc_fn) {
            continue;
        }
        bool only_freed = true;
        std::vector<llvm::CallInst *> frees;
        for (llvm::User *use : call->users()) {
            auto *free_call = llvm::dyn_cast<llvm::CallInst>(use);
            if (free_call == nullptr || free_fn == nullptr
                    || free_call->getCalledFunction() != free_fn) {
                only_freed = false;
                break;
            }
            frees.push_back(free_call);
        }
        if (!only_freed) {
            continue;
        }
        dead.insert(dead.end(), frees.begin(), frees.end());
        dead.push_back(call);
    }
    for (llvm::CallInst *call : dead) {
        call->eraseFromParent();
    }
    if (llvm::Function *allocator = m.getFunction("_lfortran_get_default_allocator")) {
        std::vector<llvm::CallInst *> unused;
        for (llvm::User *user : allocator->users()) {
            auto *call = llvm::dyn_cast<llvm::CallInst>(user);
            if (call != nullptr && call->getCalledFunction() == allocator
                    && call->user_empty()) {
                unused.push_back(call);
            }
        }
        for (llvm::CallInst *call : unused) {
            call->eraseFromParent();
        }
    }
    // The allocator is only needed to format an error that this call does
    // not take. Leave it in that block so the hot path does not call it.
    sink_call_to_its_users(m, "_lfortran_get_default_allocator");
}

static void sink_call_to_its_users(llvm::Module &m, const char *name) {
    llvm::Function *fn = m.getFunction(name);
    if (fn == nullptr) {
        return;
    }
    std::vector<llvm::CallInst *> calls;
    for (llvm::User *user : fn->users()) {
        auto *call = llvm::dyn_cast<llvm::CallInst>(user);
        if (call != nullptr && call->getCalledFunction() == fn) {
            calls.push_back(call);
        }
    }
    for (llvm::CallInst *call : calls) {
        if (call->user_empty() || call->getFunction() == nullptr) {
            continue;
        }
        llvm::DominatorTree tree(*call->getFunction());
        llvm::BasicBlock *home = nullptr;
        bool ok = true;
        for (llvm::User *user : call->users()) {
            auto *inst = llvm::dyn_cast<llvm::Instruction>(user);
            if (inst == nullptr) {
                ok = false;
                break;
            }
            llvm::BasicBlock *bb = inst->getParent();
            if (home == nullptr || tree.dominates(bb, home)) {
                home = bb;
            }
        }
        if (!ok || home == nullptr || home == call->getParent()) {
            continue;
        }
        for (llvm::User *user : call->users()) {
            auto *inst = llvm::cast<llvm::Instruction>(user);
            if (!tree.dominates(home, inst->getParent())) {
                ok = false;
                break;
            }
        }
        if (!ok) {
            continue;
        }
        llvm::Instruction *first = nullptr;
        for (llvm::Instruction &inst : *home) {
            for (llvm::Use &op : inst.operands()) {
                if (op.get() == call) {
                    first = &inst;
                    break;
                }
            }
            if (first != nullptr) {
                break;
            }
        }
        if (first != nullptr && llvm::isa<llvm::PHINode>(first)) {
            // A phi incoming is defined in the predecessor, not in the
            // join block. Moving the call in front of the phi puts a
            // non-phi before the phi and the module no longer verifies.
            // COBYLA's sequence association hits this after GVN.
            auto *phi = llvm::cast<llvm::PHINode>(first);
            llvm::BasicBlock *pred = nullptr;
            bool unique = true;
            for (unsigned i = 0; i < phi->getNumIncomingValues(); i++) {
                if (phi->getIncomingValue(i) != call) {
                    continue;
                }
                llvm::BasicBlock *inc = phi->getIncomingBlock(i);
                if (pred != nullptr && pred != inc) {
                    unique = false;
                }
                pred = inc;
            }
            bool others_ok = unique && pred != nullptr;
            if (others_ok) {
                for (llvm::User *user : call->users()) {
                    auto *inst = llvm::cast<llvm::Instruction>(user);
                    if (llvm::isa<llvm::PHINode>(inst)) {
                        continue;
                    }
                    if (!tree.dominates(pred, inst->getParent())) {
                        others_ok = false;
                        break;
                    }
                }
            }
            if (others_ok && pred->getTerminator() != nullptr) {
                call->moveBefore(pred->getTerminator());
            }
        } else if (first != nullptr) {
            call->moveBefore(first);
        } else if (llvm::Instruction *term = home->getTerminator()) {
            call->moveBefore(term);
        }
    }
}

// An <8 x double> abs-reduction is legal on AVX-512 and the SLP vectorizer
// emits it for the 10-point tail of dqk21. One zmm instruction drops the
// core frequency, so the scalar integrand calls around it get slower.
// gfortran -march=native keeps that sum in ymm. Split the 8-wide
// operations into two 4-wide ones; nothing else uses the wide value, so
// it is deleted and the backend sees ymm.
static bool is_v8f64(llvm::Type *ty) {
#if LLVM_VERSION_MAJOR >= 12
    auto *vec = llvm::dyn_cast<llvm::FixedVectorType>(ty);
#else
    auto *vec = llvm::dyn_cast<llvm::VectorType>(ty);
#endif
    return vec && vec->getElementType()->isDoubleTy()
        && vec->getNumElements() == 8;
}

static llvm::VectorType *v4f64(llvm::LLVMContext &ctx) {
    return llvm::VectorType::get(llvm::Type::getDoubleTy(ctx), 4);
}

struct V8Halves {
    llvm::Value *lo;
    llvm::Value *hi;
};

static V8Halves halves_of(llvm::Value *v, llvm::IRBuilder<> &builder,
        std::map<llvm::Value*, V8Halves> &known) {
    auto found = known.find(v);
    if (found != known.end()) {
        return found->second;
    }
    if (auto *data = llvm::dyn_cast<llvm::ConstantDataVector>(v)) {
        llvm::SmallVector<llvm::Constant*, 4> lo, hi;
        for (unsigned i = 0; i < 4; i++) {
            lo.push_back(data->getElementAsConstant(i));
            hi.push_back(data->getElementAsConstant(i + 4));
        }
        V8Halves h{llvm::ConstantVector::get(lo), llvm::ConstantVector::get(hi)};
        known[v] = h;
        return h;
    }
    llvm::report_fatal_error("cannot split an <8 x double> value");
}

static llvm::Value *broadcast4(llvm::IRBuilder<> &builder, llvm::Value *scalar) {
    llvm::VectorType *v4 = v4f64(scalar->getContext());
    llvm::Value *one = builder.CreateInsertElement(
        llvm::UndefValue::get(v4), scalar, builder.getInt64(0));
    return builder.CreateShuffleVector(one, llvm::UndefValue::get(v4),
        llvm::SmallVector<int, 4>{0, 0, 0, 0});
}

static void narrow_8wide_doubles(llvm::Function &fn) {
    std::map<llvm::Value*, V8Halves> known;
    llvm::SmallVector<llvm::Instruction*, 16> kill;
    for (llvm::BasicBlock &bb : fn) {
        for (llvm::Instruction &inst : bb) {
            llvm::IRBuilder<> builder(&inst);
            if (auto *load = llvm::dyn_cast<llvm::LoadInst>(&inst)) {
                if (!is_v8f64(load->getType())) {
                    continue;
                }
                auto *cast = llvm::dyn_cast<llvm::BitCastInst>(
                    load->getPointerOperand());
                if (cast == nullptr) {
                    continue;
                }
                llvm::Value *base = cast->getOperand(0);
                llvm::Type *v4p = v4f64(fn.getContext())->getPointerTo();
                // The 8-wide load was only 16-byte aligned. A <4 x double>
                // load assumes 32-byte alignment and faults otherwise.
                auto *lo = llvm::cast<llvm::LoadInst>(builder.CreateLoad(
                    builder.CreateBitCast(base, v4p)));
                llvm::Value *hi_ptr = builder.CreateInBoundsGEP(base,
                    builder.getInt64(4));
                auto *hi = llvm::cast<llvm::LoadInst>(builder.CreateLoad(
                    builder.CreateBitCast(hi_ptr, v4p)));
                lo->setAlignment(llvm::Align(8));
                hi->setAlignment(llvm::Align(8));
                known[load] = {lo, hi};
                kill.push_back(load);
                continue;
            }
            if (auto *shuffle = llvm::dyn_cast<llvm::ShuffleVectorInst>(&inst)) {
                if (!is_v8f64(shuffle->getType())) {
                    continue;
                }
                llvm::SmallVector<int, 8> mask;
                shuffle->getShuffleMask(mask);
                bool broadcast = true;
                for (int lane : mask) {
                    if (lane != 0) {
                        broadcast = false;
                        break;
                    }
                }
                auto *inserted = llvm::dyn_cast<llvm::InsertElementInst>(
                    shuffle->getOperand(0));
                if (!broadcast || inserted == nullptr
                        || !llvm::isa<llvm::UndefValue>(inserted->getOperand(0))) {
                    continue;
                }
                llvm::Value *splat = broadcast4(builder, inserted->getOperand(1));
                known[shuffle] = {splat, splat};
                kill.push_back(inserted);
                kill.push_back(shuffle);
                continue;
            }
            if (auto *bin = llvm::dyn_cast<llvm::BinaryOperator>(&inst)) {
                if (!is_v8f64(bin->getType())) {
                    continue;
                }
                builder.setFastMathFlags(bin->getFastMathFlags());
                V8Halves x = halves_of(bin->getOperand(0), builder, known);
                V8Halves y = halves_of(bin->getOperand(1), builder, known);
                llvm::Value *lo = builder.CreateBinOp(bin->getOpcode(), x.lo, y.lo);
                llvm::Value *hi = builder.CreateBinOp(bin->getOpcode(), x.hi, y.hi);
                known[bin] = {lo, hi};
                kill.push_back(bin);
                continue;
            }
            auto *call = llvm::dyn_cast<llvm::CallInst>(&inst);
            if (call == nullptr) {
                continue;
            }
            llvm::Function *callee = call->getCalledFunction();
            if (callee == nullptr) {
                continue;
            }
            llvm::StringRef name = callee->getName();
            if (name.startswith("llvm.fabs.v8f64")) {
                V8Halves arg = halves_of(call->getArgOperand(0), builder, known);
                llvm::Function *fabs4 = llvm::Intrinsic::getDeclaration(
                    fn.getParent(), llvm::Intrinsic::fabs,
                    {v4f64(fn.getContext())});
                builder.setFastMathFlags(call->getFastMathFlags());
                known[call] = {
                    builder.CreateCall(fabs4, {arg.lo}),
                    builder.CreateCall(fabs4, {arg.hi})
                };
                kill.push_back(call);
                continue;
            }
            if (!name.startswith("llvm.experimental.vector.reduce")
                    || call->getNumArgOperands() < 2
                    || !is_v8f64(call->getArgOperand(1)->getType())) {
                continue;
            }
            V8Halves arg = halves_of(call->getArgOperand(1), builder, known);
            builder.setFastMathFlags(call->getFastMathFlags());
            llvm::Value *sum = call->getArgOperand(0);
            for (llvm::Value *half : {arg.lo, arg.hi}) {
                for (unsigned lane = 0; lane < 4; lane++) {
                    sum = builder.CreateFAdd(sum,
                        builder.CreateExtractElement(half, lane));
                }
            }
            call->replaceAllUsesWith(sum);
            kill.push_back(call);
        }
    }
    // Users are later in the block than their operands, so the reverse
    // order drops each wide instruction after its users are gone.
    for (llvm::Instruction *inst : llvm::reverse(kill)) {
        if (inst->use_empty()) {
            inst->eraseFromParent();
        }
    }
}

static bool calls_indirectly(const llvm::Function &fn) {
    for (const llvm::BasicBlock &bb : fn) {
        for (const llvm::Instruction &inst : bb) {
            auto *call = llvm::dyn_cast<llvm::CallInst>(&inst);
            if (call != nullptr && !call->isInlineAsm()
                    && call->getCalledFunction() == nullptr) {
                return true;
            }
        }
    }
    return false;
}

static void narrow_8wide_doubles(llvm::Module &m) {
    for (llvm::Function &fn : m) {
        // The loop vectorizer honors prefer-vector-width. LLVM 11's SLP
        // horizontal reduction does not: it builds an 8-wide vector and
        // leaves the zmm op in place, which slows the scalar calls around
        // a Kronrod tail. Rewrite that reduction when this routine calls
        // through a procedure argument. A pure vector kernel is left alone.
        if (!fn.empty() && calls_indirectly(fn)) {
            narrow_8wide_doubles(fn);
        }
    }
    std::vector<llvm::Function *> unused;
    for (llvm::Function &fn : m) {
        if (fn.isDeclaration() && fn.use_empty()
                && fn.getName().find("v8f64") != llvm::StringRef::npos) {
            unused.push_back(&fn);
        }
    }
    for (llvm::Function *fn : unused) {
        fn->eraseFromParent();
    }
}

static void lower_vector_exp_to_libmvec(llvm::Module &m) {
    llvm::Triple triple(m.getTargetTriple());
    if (!triple.isX86() || triple.isArch32Bit()) {
        return;
    }
    std::vector<llvm::CallInst *> calls;
    for (llvm::Function &f : m) {
        for (llvm::BasicBlock &bb : f) {
            for (llvm::Instruction &inst : bb) {
                auto *call = llvm::dyn_cast<llvm::CallInst>(&inst);
                if (call == nullptr || call->getIntrinsicID() != llvm::Intrinsic::exp) {
                    continue;
                }
#if LLVM_VERSION_MAJOR >= 11
                if (llvm::isa<llvm::FixedVectorType>(call->getType())) {
#else
                if (llvm::isa<llvm::VectorType>(call->getType())) {
#endif
                    calls.push_back(call);
                }
            }
        }
    }
    for (llvm::CallInst *call : calls) {
#if LLVM_VERSION_MAJOR >= 11
        auto *vec = llvm::cast<llvm::FixedVectorType>(call->getType());
#else
        auto *vec = llvm::cast<llvm::VectorType>(call->getType());
#endif
        unsigned width = vec->getNumElements();
        bool is_float = vec->getElementType()->isFloatTy();
        if (!is_float && !vec->getElementType()->isDoubleTy()) {
            continue;
        }
        bool avx2 = false;
        if (llvm::Function *parent = call->getFunction()) {
            if (parent->hasFnAttribute("target-features")) {
                llvm::Attribute attr = parent->getFnAttribute("target-features");
                if (attr.getValueAsString().contains("+avx2")) {
                    avx2 = true;
                }
            }
        }
        const char *name = libmvec_exp_name(is_float, width, avx2);
        if (name == nullptr) {
            continue;
        }
        llvm::FunctionType *fty = llvm::FunctionType::get(vec, {vec}, false);
        llvm::FunctionCallee fn = m.getOrInsertFunction(name, fty);
        llvm::CallInst *vec_call = llvm::CallInst::Create(
            fty, fn.getCallee(), {call->getArgOperand(0)}, "", call);
        vec_call->copyFastMathFlags(call);
        vec_call->setTailCallKind(call->getTailCallKind());
        call->replaceAllUsesWith(vec_call);
        call->eraseFromParent();
    }
}

// GVN load PRE turns x(i) into the value loaded as x(i+1) on the previous
// iteration. That phi is a floating-point recurrence. LLVM 11's loop
// vectorizer will not vectorize an FP phi unless it is a reduction, so the
// Rosenbrock gradient stays scalar (vmulsd) while gfortran emits mulpd.
// The widened loads are worth more than the eliminated scalar load.
static void disable_load_pre() {
    llvm::StringMap<llvm::cl::Option*> &options
        = llvm::cl::getRegisteredOptions();
    auto option = options.find("enable-load-pre");
    if (option != options.end() && option->second->getNumOccurrences() == 0) {
        option->second->addOccurrence(0, "enable-load-pre", "false");
    }
}

// A column-major element wy(k, j) is one i64 GEP whose index is
// sext(k) plus a column offset. LLVM 11 then gathers with vgatherqpd.
// gfortran -march=native uses vgatherdpd, which keeps the loaded index
// in i32. Splitting the unit-stride sext off the i64 offset is the same
// address: the i32 index is sign-extended by the GEP, and a negative
// constant such as the -1 of a 1-based subscript stays on the i64 side so
// it cannot overflow. The intermediate pointer is not inbounds, because
// that constant can sit one element before the allocation.
//
// A reverse subscript such as ic = idp2 - i is widened to i64 before this
// pass, so it is no longer a sext of an i32 value and is left for loop
// strength reduction. What remains is the gathered index.
struct SextAffine {
    llvm::Value* i32;
    int64_t off;
};

static bool add_i64(int64_t a, int64_t b, int64_t& out) {
    return !__builtin_add_overflow(a, b, &out);
}

static SextAffine* match_sext_affine(llvm::Value* v, SextAffine& out, int depth) {
    if (v == nullptr || depth > 8) {
        return nullptr;
    }
    if (auto* sext = llvm::dyn_cast<llvm::SExtInst>(v)) {
        if (sext->getOperand(0)->getType()->isIntegerTy(32)) {
            out.i32 = sext->getOperand(0);
            out.off = 0;
            return &out;
        }
        return nullptr;
    }
    auto* bin = llvm::dyn_cast<llvm::BinaryOperator>(v);
    if (bin == nullptr) {
        return nullptr;
    }
    unsigned op = bin->getOpcode();
    if (op == llvm::Instruction::Mul) {
        llvm::ConstantInt* scale = nullptr;
        llvm::Value* other = nullptr;
        if (auto* c = llvm::dyn_cast<llvm::ConstantInt>(bin->getOperand(1))) {
            scale = c;
            other = bin->getOperand(0);
        } else if (auto* c = llvm::dyn_cast<llvm::ConstantInt>(bin->getOperand(0))) {
            scale = c;
            other = bin->getOperand(1);
        }
        if (scale == nullptr || !scale->isOne()) {
            return nullptr;
        }
        return match_sext_affine(other, out, depth + 1);
    }
    if (op != llvm::Instruction::Add && op != llvm::Instruction::Sub) {
        return nullptr;
    }
    llvm::ConstantInt* c = llvm::dyn_cast<llvm::ConstantInt>(bin->getOperand(1));
    llvm::Value* other = bin->getOperand(0);
    if (c == nullptr && op == llvm::Instruction::Add) {
        c = llvm::dyn_cast<llvm::ConstantInt>(bin->getOperand(0));
        other = bin->getOperand(1);
    }
    if (c == nullptr || !c->getValue().isSignedIntN(63)) {
        return nullptr;
    }
    if (match_sext_affine(other, out, depth + 1) == nullptr) {
        return nullptr;
    }
    int64_t delta = c->getSExtValue();
    if (op == llvm::Instruction::Sub) {
        delta = -delta;
    }
    int64_t sum = 0;
    if (!add_i64(out.off, delta, sum)) {
        return nullptr;
    }
    out.off = sum;
    return &out;
}

static bool narrow_gather_index(llvm::GetElementPtrInst* gep) {
    if (gep->getNumIndices() != 1) {
        return false;
    }
    llvm::Type* ty = gep->getSourceElementType();
    if (ty->isAggregateType()) {
        return false;
    }
    llvm::Value* idx = gep->getOperand(1);
    if (!idx->getType()->isIntegerTy(64)) {
        return false;
    }
    llvm::Value* key = nullptr;
    llvm::Value* rest = nullptr;
    int64_t off = 0;
    SextAffine matched;
    if (match_sext_affine(idx, matched, 0) != nullptr) {
        key = matched.i32;
        off = matched.off;
    } else if (auto* add = llvm::dyn_cast<llvm::BinaryOperator>(idx)) {
        if (add->getOpcode() == llvm::Instruction::Add) {
            SextAffine side;
            if (match_sext_affine(add->getOperand(0), side, 0) != nullptr) {
                key = side.i32;
                off = side.off;
                rest = add->getOperand(1);
            } else if (match_sext_affine(add->getOperand(1), side, 0) != nullptr) {
                key = side.i32;
                off = side.off;
                rest = add->getOperand(0);
            }
        }
    }
    if (key == nullptr) {
        return false;
    }
    llvm::IRBuilder<> builder(gep);
    llvm::Value* base = gep->getPointerOperand();
    if (off != 0) {
        llvm::Value* coff = llvm::ConstantInt::getSigned(idx->getType(), off);
        rest = rest == nullptr ? coff : builder.CreateAdd(rest, coff);
    }
    if (rest != nullptr) {
        base = builder.CreateGEP(ty, base, rest);
    }
    // The adjusted base can be one element before the allocation (the
    // usual 1-based subscript). An inbounds GEP from that pointer is poison.
    bool final_inbounds = gep->isInBounds() && rest == nullptr;
    llvm::Value* narrowed = final_inbounds
        ? builder.CreateInBoundsGEP(ty, base, key)
        : builder.CreateGEP(ty, base, key);
    gep->replaceAllUsesWith(narrowed);
    gep->eraseFromParent();
    return true;
}

// (wy * wv) / theta keeps two vector multiplies. Under fast-math this is
// wy * (wv / theta), and wv/theta does not depend on the gathered wy, so
// the later LICM pass lifts it. The shallower factor is the one divided:
// the gathered value has the longer address chain.
static int value_depth(llvm::Value* v, int depth) {
    auto* inst = llvm::dyn_cast<llvm::Instruction>(v);
    if (inst == nullptr || depth > 12) {
        return 0;
    }
    int best = 0;
    for (llvm::Value* op : inst->operands()) {
        best = std::max(best, value_depth(op, depth + 1));
    }
    return best + 1;
}

static void reassociate_invariant_quotient(llvm::Module& m) {
    for (llvm::Function& fn : m) {
        if (fn.empty()) {
            continue;
        }
        llvm::SmallVector<llvm::BinaryOperator*, 8> divs;
        for (llvm::BasicBlock& bb : fn) {
            for (llvm::Instruction& inst : bb) {
                auto* div = llvm::dyn_cast<llvm::BinaryOperator>(&inst);
                if (div == nullptr || div->getOpcode() != llvm::Instruction::FDiv
                        || !div->getFastMathFlags().allowReassoc()) {
                    continue;
                }
                auto* mul = llvm::dyn_cast<llvm::BinaryOperator>(div->getOperand(0));
                if (mul == nullptr || mul->getOpcode() != llvm::Instruction::FMul
                        || !mul->hasOneUse()
                        || !mul->getFastMathFlags().allowReassoc()) {
                    continue;
                }
                divs.push_back(div);
            }
        }
        for (llvm::BinaryOperator* div : divs) {
            auto* mul = llvm::cast<llvm::BinaryOperator>(div->getOperand(0));
            llvm::Value* left = mul->getOperand(0);
            llvm::Value* right = mul->getOperand(1);
            llvm::Value* shallow = value_depth(left, 0) <= value_depth(right, 0)
                ? left : right;
            llvm::Value* deep = shallow == left ? right : left;
            llvm::Value* denom = div->getOperand(1);
            // Place wv/theta next to those loads, which are outside the
            // inner loop, so a later pass cannot sink 1/theta back in and
            // multiply by wv on every element.
            llvm::Instruction* insert_after = nullptr;
            auto* shallow_i = llvm::dyn_cast<llvm::Instruction>(shallow);
            auto* denom_i = llvm::dyn_cast<llvm::Instruction>(denom);
            if (shallow_i != nullptr && denom_i != nullptr
                    && shallow_i->getParent() == denom_i->getParent()) {
                insert_after = shallow_i->comesBefore(denom_i) ? denom_i : shallow_i;
            } else if (denom_i != nullptr && shallow_i == nullptr) {
                insert_after = denom_i;
            } else if (shallow_i != nullptr && denom_i == nullptr) {
                insert_after = shallow_i;
            }
            llvm::IRBuilder<> builder(div);
            if (insert_after != nullptr && insert_after->getNextNode() != nullptr
                    && insert_after->getParent() != div->getParent()) {
                builder.SetInsertPoint(insert_after->getNextNode());
            }
            builder.setFastMathFlags(div->getFastMathFlags());
            llvm::Value* scale = builder.CreateFDiv(shallow, denom);
            // Without reassoc on this multiply, the Reassociate pass cannot
            // turn a*(wv/theta) back into (a*wv)*(1/theta) and leave both
            // multiplies in the loop.
            llvm::FastMathFlags locked = div->getFastMathFlags();
            locked.setAllowReassoc(false);
            builder.setFastMathFlags(locked);
            llvm::Value* prod = builder.CreateFMul(deep, scale);
            div->replaceAllUsesWith(prod);
            div->eraseFromParent();
            if (mul->use_empty()) {
                mul->eraseFromParent();
            }
        }
    }
}

// sext(sub nsw a, b) is not an induction, so loop strength reduction leaves
// the sign extension and the address arithmetic in the loop. sub nsw of
// the widened operands is the same value and is affine in each operand.
static void widen_nsw_index_arithmetic(llvm::Function& fn) {
    bool changed = true;
    while (changed) {
        changed = false;
        llvm::SmallVector<llvm::SExtInst*, 8> sexts;
        for (llvm::BasicBlock& bb : fn) {
            for (llvm::Instruction& inst : bb) {
                auto* sext = llvm::dyn_cast<llvm::SExtInst>(&inst);
                if (sext == nullptr || !sext->getSrcTy()->isIntegerTy(32)
                        || !sext->getDestTy()->isIntegerTy(64)) {
                    continue;
                }
                auto* bin = llvm::dyn_cast<llvm::BinaryOperator>(sext->getOperand(0));
                if (bin == nullptr || !bin->hasNoSignedWrap()) {
                    continue;
                }
                unsigned op = bin->getOpcode();
                if (op != llvm::Instruction::Add && op != llvm::Instruction::Sub
                        && op != llvm::Instruction::Mul) {
                    continue;
                }
                sexts.push_back(sext);
            }
        }
        for (llvm::SExtInst* sext : sexts) {
            if (sext->getParent() == nullptr) {
                continue;
            }
            auto* bin = llvm::cast<llvm::BinaryOperator>(sext->getOperand(0));
            llvm::IRBuilder<> builder(sext);
            llvm::Type* wide = sext->getType();
            llvm::Value* left = builder.CreateSExt(bin->getOperand(0), wide);
            llvm::Value* right = builder.CreateSExt(bin->getOperand(1), wide);
            llvm::Value* widened = nullptr;
            if (bin->getOpcode() == llvm::Instruction::Add) {
                widened = builder.CreateNSWAdd(left, right);
            } else if (bin->getOpcode() == llvm::Instruction::Sub) {
                widened = builder.CreateNSWSub(left, right);
            } else {
                widened = builder.CreateNSWMul(left, right);
            }
            sext->replaceAllUsesWith(widened);
            sext->eraseFromParent();
            changed = true;
        }
    }
}

static void prepare_index_arithmetic(llvm::Module& m) {
    llvm::legacy::FunctionPassManager early(&m);
    early.add(llvm::createPromoteMemoryToRegisterPass());
    early.add(llvm::createInstructionCombiningPass());
    early.doInitialization();
    for (llvm::Function& fn : m) {
        if (!fn.empty()) {
            early.run(fn);
        }
    }
    early.doFinalization();
    for (llvm::Function& fn : m) {
        if (!fn.empty()) {
            widen_nsw_index_arithmetic(fn);
        }
    }
}

static void narrow_gather_indices(llvm::Module& m) {
    for (llvm::Function& fn : m) {
        if (fn.empty()) {
            continue;
        }
        llvm::SmallVector<llvm::GetElementPtrInst*, 16> geps;
        for (llvm::BasicBlock& bb : fn) {
            for (llvm::Instruction& inst : bb) {
                if (auto* gep = llvm::dyn_cast<llvm::GetElementPtrInst>(&inst)) {
                    geps.push_back(gep);
                }
            }
        }
        for (llvm::GetElementPtrInst* gep : geps) {
            narrow_gather_index(gep);
        }
    }
}

// AVX-512 lowers a scalar select to a merging masked vmovsd. In r1mpyq that
// move is the hot instruction: both sides of the Givens test are already
// computed, and the mask merge costs more than the arithmetic. A branch
// keeps the value in an xmm. Vector selects are left alone.
static void lower_avx512_scalar_fp_selects(llvm::Function &fn) {
    if (fn.empty() || !fn.hasFnAttribute("target-features")
            || fn.getFnAttribute("target-features").getValueAsString().find(
                "+avx512f") == llvm::StringRef::npos) {
        return;
    }
    llvm::SmallVector<llvm::SelectInst*, 8> selects;
    for (llvm::BasicBlock &bb : fn) {
        for (llvm::Instruction &inst : bb) {
            auto *sel = llvm::dyn_cast<llvm::SelectInst>(&inst);
            if (sel == nullptr) {
                continue;
            }
            llvm::Type *ty = sel->getType();
            if (!ty->isFloatTy() && !ty->isDoubleTy()) {
                continue;
            }
            if (!sel->getCondition()->getType()->isIntegerTy(1)) {
                continue;
            }
            selects.push_back(sel);
        }
    }
    for (llvm::SelectInst *sel : llvm::reverse(selects)) {
        llvm::Function *parent = sel->getFunction();
        llvm::BasicBlock *head = sel->getParent();
        llvm::BasicBlock *tail = head->splitBasicBlock(sel, "select.join");
        head->getTerminator()->eraseFromParent();
        llvm::BasicBlock *when_true = llvm::BasicBlock::Create(
            parent->getContext(), "select.true", parent, tail);
        llvm::BasicBlock *when_false = llvm::BasicBlock::Create(
            parent->getContext(), "select.false", parent, tail);
        llvm::IRBuilder<> builder(head);
        builder.CreateCondBr(sel->getCondition(), when_true, when_false);
        builder.SetInsertPoint(when_true);
        builder.CreateBr(tail);
        builder.SetInsertPoint(when_false);
        builder.CreateBr(tail);
        llvm::PHINode *phi = llvm::PHINode::Create(
            sel->getType(), 2, "select.phi", sel);
        phi->addIncoming(sel->getTrueValue(), when_true);
        phi->addIncoming(sel->getFalseValue(), when_false);
        sel->replaceAllUsesWith(phi);
        sel->eraseFromParent();
    }
}

static void lower_avx512_scalar_fp_selects(llvm::Module &m) {
    for (llvm::Function &fn : m) {
        lower_avx512_scalar_fp_selects(fn);
    }
}

// `ix = 1; if (inc < 0) ix = (1 - n)*inc + 1` is the BLAS setup for a
// negative increment. --fast folds it to a select, so the multiply runs
// on the positive increments that `dcopy_` actually sees. Put the
// multiply back on the cold side of the branch.
static bool keep_negative_stride_off_fast_path(llvm::Function &fn) {
    if (fn.empty()) return false;
    llvm::SmallVector<llvm::SelectInst*, 4> selects;
    for (llvm::BasicBlock &bb : fn) {
        for (llvm::Instruction &inst : bb) {
            auto *sel = llvm::dyn_cast<llvm::SelectInst>(&inst);
            if (sel == nullptr || !sel->getType()->isIntegerTy()) continue;
            auto *cmp = llvm::dyn_cast<llvm::ICmpInst>(sel->getCondition());
            if (cmp == nullptr || cmp->getPredicate() != llvm::ICmpInst::ICMP_SLT) {
                continue;
            }
            auto *zero = llvm::dyn_cast<llvm::ConstantInt>(cmp->getOperand(1));
            auto *one = llvm::dyn_cast<llvm::ConstantInt>(sel->getFalseValue());
            if (zero == nullptr || !zero->isZero() || one == nullptr || !one->isOne()) {
                continue;
            }
            auto *add = llvm::dyn_cast<llvm::BinaryOperator>(sel->getTrueValue());
            if (add == nullptr || add->getOpcode() != llvm::Instruction::Add
                    || !add->hasOneUse()) {
                continue;
            }
            auto *mul = llvm::dyn_cast<llvm::BinaryOperator>(add->getOperand(0));
            if (mul == nullptr || mul->getOpcode() != llvm::Instruction::Mul
                    || !mul->hasOneUse()) {
                continue;
            }
            llvm::Value *inc = cmp->getOperand(0);
            if (mul->getOperand(0) != inc && mul->getOperand(1) != inc) continue;
            selects.push_back(sel);
        }
    }
    if (selects.empty()) return false;
    llvm::LLVMContext &ctx = fn.getContext();
    llvm::MDBuilder weights(ctx);
    for (llvm::SelectInst *sel : llvm::reverse(selects)) {
        auto *add = llvm::cast<llvm::BinaryOperator>(sel->getTrueValue());
        auto *mul = llvm::cast<llvm::BinaryOperator>(add->getOperand(0));
        llvm::BasicBlock *head = sel->getParent();
        llvm::BasicBlock *tail = head->splitBasicBlock(sel, "stride.fast");
        head->getTerminator()->eraseFromParent();
        llvm::BasicBlock *neg = llvm::BasicBlock::Create(
            ctx, "stride.neg", &fn, tail);
        llvm::IRBuilder<> builder(head);
        llvm::BranchInst *br = builder.CreateCondBr(sel->getCondition(), neg, tail);
        // Positive increments are the calls that matter. A cold true
        // edge keeps the multiply off that path through codegen.
        br->setMetadata(llvm::LLVMContext::MD_prof,
            weights.createBranchWeights(1, 2000));
        builder.SetInsertPoint(neg);
        builder.CreateBr(tail);
        mul->moveBefore(neg->getTerminator());
        add->moveBefore(neg->getTerminator());
        llvm::PHINode *phi = llvm::PHINode::Create(
            sel->getType(), 2, "stride.ix", sel);
        phi->addIncoming(add, neg);
        phi->addIncoming(sel->getFalseValue(), head);
        sel->replaceAllUsesWith(phi);
        sel->eraseFromParent();
    }
    return true;
}

// The index of a load is `iv` plus a constant. A backward index
// (`m - j`) or a runtime stride is left scalar: wrapping those in the
// vector header made `basym` and `dwght` slower.
static bool forward_unit_index(llvm::Value *ptr, llvm::PHINode *iv) {
    auto *gep = llvm::dyn_cast<llvm::GetElementPtrInst>(ptr);
    if (gep == nullptr) {
        return false;
    }
    llvm::Value *idx = gep->getOperand(gep->getNumOperands() - 1);
    while (auto *add = llvm::dyn_cast<llvm::BinaryOperator>(idx)) {
        if (add->getOpcode() != llvm::Instruction::Add) {
            return false;
        }
        if (llvm::isa<llvm::ConstantInt>(add->getOperand(1))) {
            idx = add->getOperand(0);
        } else if (llvm::isa<llvm::ConstantInt>(add->getOperand(0))) {
            idx = add->getOperand(1);
        } else {
            return false;
        }
    }
    return idx == iv;
}

// A strict `s = s + a*b` loop is not vectorized: the reduction is not
// associative, and runtime unrolling is off. gfortran -O3 -march=native
// multiplies a whole vector of products and adds those lanes into the
// accumulator in order, which is the same rounding as the scalar loop.
// `width` is 4 when the target has AVX and 2 otherwise. Only when the
// fmul and fadd carry no fast-math flags, and both loads step one
// element forward with the induction variable.
static bool widen_strict_product_reduction(llvm::BasicBlock *loop,
        unsigned width) {
    if (loop == nullptr || loop->getTerminator() == nullptr) {
        return false;
    }
    auto *br = llvm::dyn_cast<llvm::BranchInst>(loop->getTerminator());
    if (br == nullptr || !br->isConditional()) {
        return false;
    }
    bool back_on_true = br->getSuccessor(0) == loop;
    bool back_on_false = br->getSuccessor(1) == loop;
    if (back_on_true == back_on_false) {
        return false;
    }
    llvm::BasicBlock *exit = back_on_true ? br->getSuccessor(1) : br->getSuccessor(0);
    auto *cmp = llvm::dyn_cast<llvm::ICmpInst>(br->getCondition());
    if (cmp == nullptr || cmp->getPredicate() != llvm::ICmpInst::ICMP_EQ) {
        return false;
    }
    llvm::PHINode *iv = nullptr;
    llvm::PHINode *acc = nullptr;
    for (llvm::PHINode &phi : loop->phis()) {
        if (phi.getNumIncomingValues() != 2) {
            return false;
        }
        if (phi.getType()->isIntegerTy(64) && iv == nullptr) {
            iv = &phi;
        } else if (phi.getType()->isDoubleTy() && acc == nullptr) {
            acc = &phi;
        } else {
            return false;
        }
    }
    if (iv == nullptr || acc == nullptr) {
        return false;
    }
    if (iv->getBasicBlockIndex(loop) < 0 || acc->getBasicBlockIndex(loop) < 0) {
        return false;
    }
    int iv_pre = iv->getBasicBlockIndex(loop) == 0 ? 1 : 0;
    llvm::BasicBlock *pre = iv->getIncomingBlock(iv_pre);
    if (acc->getIncomingBlock(iv_pre) != pre) {
        // The two phis must share the same predecessor order.
        int acc_pre = acc->getBasicBlockIndex(loop) == 0 ? 1 : 0;
        if (acc->getIncomingBlock(acc_pre) != pre) {
            return false;
        }
    }
    llvm::Value *start = iv->getIncomingValueForBlock(pre);
    llvm::Value *start_acc = acc->getIncomingValueForBlock(pre);
    auto *step = llvm::dyn_cast<llvm::BinaryOperator>(iv->getIncomingValueForBlock(loop));
    if (step == nullptr || step->getOpcode() != llvm::Instruction::Add) {
        return false;
    }
    if (step->getOperand(0) != iv || !llvm::isa<llvm::ConstantInt>(step->getOperand(1))
            || !llvm::cast<llvm::ConstantInt>(step->getOperand(1))->isOne()) {
        return false;
    }
    auto *sum = llvm::dyn_cast<llvm::BinaryOperator>(acc->getIncomingValueForBlock(loop));
    if (sum == nullptr || sum->getOpcode() != llvm::Instruction::FAdd) {
        return false;
    }
    if (sum->getFastMathFlags().any() || sum->getOperand(0) != acc) {
        return false;
    }
    auto *prod = llvm::dyn_cast<llvm::BinaryOperator>(sum->getOperand(1));
    if (prod == nullptr || prod->getOpcode() != llvm::Instruction::FMul
            || prod->getFastMathFlags().any() || !prod->getType()->isDoubleTy()) {
        return false;
    }
    auto *load0 = llvm::dyn_cast<llvm::LoadInst>(prod->getOperand(0));
    auto *load1 = llvm::dyn_cast<llvm::LoadInst>(prod->getOperand(1));
    if (load0 == nullptr || load1 == nullptr) {
        return false;
    }
    if (!forward_unit_index(load0->getPointerOperand(), iv)
            || (load0 != load1 && !forward_unit_index(
                load1->getPointerOperand(), iv))) {
        return false;
    }
    llvm::Value *trip = nullptr;
    if (cmp->getOperand(0) == iv) {
        trip = cmp->getOperand(1);
    } else if (cmp->getOperand(1) == iv) {
        trip = cmp->getOperand(0);
    } else {
        return false;
    }
    if (llvm::isa<llvm::Instruction>(trip)
            && llvm::cast<llvm::Instruction>(trip)->getParent() == loop) {
        return false;
    }
    if (start->getType() != iv->getType() || trip->getType() != iv->getType()) {
        return false;
    }
    for (llvm::Instruction &inst : *loop) {
        if (inst.mayWriteToMemory() || llvm::isa<llvm::CallBase>(inst)) {
            return false;
        }
    }
    for (llvm::Instruction &inst : *loop) {
        for (llvm::User *user : inst.users()) {
            auto *use = llvm::dyn_cast<llvm::Instruction>(user);
            if (use == nullptr) {
                return false;
            }
            if (use->getParent() == loop) {
                continue;
            }
            // The sum is the value the loop produces. idd_houseapp multiplies
            // it by scal in the next block, rather than passing it through a phi.
            if (&inst == sum) {
                continue;
            }
            if (!llvm::isa<llvm::PHINode>(use) || use->getParent() != exit) {
                return false;
            }
        }
    }
    for (llvm::PHINode &phi : exit->phis()) {
        llvm::Value *incoming = phi.getIncomingValueForBlock(loop);
        if (incoming == sum || incoming == iv || incoming == step) {
            continue;
        }
        if (auto *def = llvm::dyn_cast<llvm::Instruction>(incoming)) {
            if (def->getParent() == loop) {
                return false;
            }
        }
    }

    llvm::Function *fn = loop->getParent();
    llvm::LLVMContext &ctx = fn->getContext();
    const std::string tag = "dot" + std::to_string(width);
    llvm::BasicBlock *head = llvm::BasicBlock::Create(ctx, tag + ".head", fn, loop);
    llvm::BasicBlock *vec = llvm::BasicBlock::Create(ctx, tag + ".vec", fn, loop);
    llvm::BasicBlock *mid = llvm::BasicBlock::Create(ctx, tag + ".mid", fn, loop);
    llvm::BasicBlock *rest = llvm::BasicBlock::Create(ctx, tag + ".rest", fn, loop);
    llvm::BasicBlock *join = llvm::BasicBlock::Create(ctx, tag + ".join", fn, loop);
    auto abandon = [&]() {
        join->eraseFromParent();
        rest->eraseFromParent();
        mid->eraseFromParent();
        vec->eraseFromParent();
        head->eraseFromParent();
        return false;
    };
    llvm::Type *i64 = iv->getType();
    llvm::Constant *one = llvm::ConstantInt::get(i64, 1);
    llvm::Constant *width_c = llvm::ConstantInt::get(i64, width);
    llvm::Constant *align_mask = llvm::ConstantInt::get(i64, ~uint64_t(width - 1));

    llvm::IRBuilder<> hb(head);
    llvm::Value *niter = hb.CreateAdd(hb.CreateSub(trip, start), one);
    llvm::Value *nvec = hb.CreateAnd(niter, align_mask);
    llvm::Value *vec_end = hb.CreateAdd(start, nvec);
    llvm::Value *trip_plus = hb.CreateAdd(trip, one);
    hb.CreateCondBr(hb.CreateICmpNE(nvec, llvm::ConstantInt::get(i64, 0)), vec, mid);

    auto *ivv = llvm::PHINode::Create(i64, 2, tag + ".iv", vec);
    auto *accv = llvm::PHINode::Create(acc->getType(), 2, tag + ".acc", vec);
    ivv->addIncoming(start, head);
    accv->addIncoming(start_acc, head);
    llvm::IRBuilder<> vb(vec);
    auto clone_at = [&](llvm::IRBuilder<> &b, llvm::Value *lane)
            -> std::pair<llvm::Value*, llvm::Value*> {
        std::set<llvm::Instruction*> deps;
        std::function<void(llvm::Value*)> walk = [&](llvm::Value *v) {
            auto *inst = llvm::dyn_cast<llvm::Instruction>(v);
            if (inst == nullptr || inst->getParent() != loop) {
                return;
            }
            if (!deps.insert(inst).second) {
                return;
            }
            for (llvm::Use &op : inst->operands()) {
                walk(op.get());
            }
        };
        walk(prod->getOperand(0));
        walk(prod->getOperand(1));
        llvm::ValueToValueMapTy vm;
        vm[iv] = lane;
        llvm::Value *left = nullptr;
        llvm::Value *right = nullptr;
        for (llvm::Instruction &inst : *loop) {
            // The induction phi is remapped to the lane value. Cloning it
            // would put a phi in the middle of the block.
            if (!deps.count(&inst) || llvm::isa<llvm::PHINode>(&inst)) {
                continue;
            }
            llvm::Instruction *cloned = inst.clone();
            vm[&inst] = cloned;
            llvm::RemapInstruction(cloned, vm,
                llvm::RF_NoModuleLevelChanges | llvm::RF_IgnoreMissingLocals);
            b.Insert(cloned);
            if (&inst == prod->getOperand(0)) {
                left = cloned;
            }
            if (&inst == prod->getOperand(1)) {
                right = cloned;
            }
        }
        return {left, right};
    };
    llvm::SmallVector<std::pair<llvm::Value*, llvm::Value*>, 4> lanes;
    for (unsigned lane = 0; lane < width; ++lane) {
        llvm::Value *at = lane == 0 ? static_cast<llvm::Value*>(ivv)
            : vb.CreateAdd(ivv, llvm::ConstantInt::get(i64, lane));
        lanes.push_back(clone_at(vb, at));
        if (lanes.back().first == nullptr || lanes.back().second == nullptr) {
            return abandon();
        }
    }
    llvm::Type *vty = llvm::VectorType::get(prod->getType(), width);
    llvm::Value *undef = llvm::UndefValue::get(vty);
    llvm::Value *lhs = undef;
    llvm::Value *rhs = undef;
    for (unsigned lane = 0; lane < width; ++lane) {
        lhs = vb.CreateInsertElement(lhs, lanes[lane].first, vb.getInt32(lane));
        rhs = vb.CreateInsertElement(rhs, lanes[lane].second, vb.getInt32(lane));
    }
    llvm::Value *wide = vb.CreateFMul(lhs, rhs);
    llvm::Value *folded = accv;
    for (unsigned lane = 0; lane < width; ++lane) {
        folded = vb.CreateFAdd(folded,
            vb.CreateExtractElement(wide, vb.getInt32(lane)));
    }
    llvm::Value *ivn = vb.CreateAdd(ivv, width_c);
    vb.CreateCondBr(vb.CreateICmpEQ(ivn, vec_end), mid, vec);
    ivv->addIncoming(ivn, vec);
    accv->addIncoming(folded, vec);

    auto *ivm = llvm::PHINode::Create(i64, 2, tag + ".iv.mid", mid);
    auto *accm = llvm::PHINode::Create(acc->getType(), 2, tag + ".acc.mid", mid);
    ivm->addIncoming(start, head);
    ivm->addIncoming(vec_end, vec);
    accm->addIncoming(start_acc, head);
    accm->addIncoming(folded, vec);
    llvm::IRBuilder<> mb(mid);
    mb.CreateCondBr(mb.CreateICmpSGT(ivm, trip), join, rest);

    // The tail is one, two or three scalar products, still in order.
    auto *ivr = llvm::PHINode::Create(i64, 2, tag + ".iv.rest", rest);
    auto *accr = llvm::PHINode::Create(acc->getType(), 2, tag + ".acc.rest", rest);
    ivr->addIncoming(ivm, mid);
    accr->addIncoming(accm, mid);
    llvm::IRBuilder<> rb(rest);
    auto rest_pair = clone_at(rb, ivr);
    if (rest_pair.first == nullptr || rest_pair.second == nullptr) {
        return abandon();
    }
    llvm::Value *ps = rb.CreateFMul(rest_pair.first, rest_pair.second);
    llvm::Value *ss = rb.CreateFAdd(accr, ps);
    llvm::Value *ivr_next = rb.CreateAdd(ivr, one);
    rb.CreateCondBr(rb.CreateICmpSGT(ivr_next, trip), join, rest);
    ivr->addIncoming(ivr_next, rest);
    accr->addIncoming(ss, rest);

    auto *accj = llvm::PHINode::Create(acc->getType(), 2, tag + ".acc.join", join);
    accj->addIncoming(accm, mid);
    accj->addIncoming(ss, rest);
    llvm::IRBuilder<> jb(join);
    jb.CreateBr(exit);

    auto *prebr = llvm::cast<llvm::BranchInst>(pre->getTerminator());
    for (unsigned i = 0; i < prebr->getNumSuccessors(); ++i) {
        if (prebr->getSuccessor(i) == loop) {
            prebr->setSuccessor(i, head);
        }
    }
    for (llvm::PHINode &phi : exit->phis()) {
        int idx = phi.getBasicBlockIndex(loop);
        if (idx < 0) {
            continue;
        }
        llvm::Value *incoming = phi.getIncomingValue(idx);
        if (incoming == sum) {
            phi.setIncomingValue(idx, accj);
        } else if (incoming == iv) {
            phi.setIncomingValue(idx, trip);
        } else if (incoming == step) {
            phi.setIncomingValue(idx, trip_plus);
        }
        phi.setIncomingBlock(idx, join);
    }
    llvm::SmallVector<llvm::Use*, 8> produced;
    for (llvm::Use &use : sum->uses()) {
        auto *user = llvm::cast<llvm::Instruction>(use.getUser());
        if (user->getParent() != loop) {
            produced.push_back(&use);
        }
    }
    for (llvm::Use *use : produced) {
        use->set(accj);
    }
    loop->eraseFromParent();
    return true;
}

// A pure copy with a runtime stride becomes an AVX-512 gather/scatter.
// The short trips in `dcopy_` are faster as a scalar pointer step, which
// is what gfortran emits. A loop that also does arithmetic, such as the
// inner product `a(i, k) * b(k, j)`, keeps the vector plan: one of those
// streams has a constant step.
static bool is_runtime_step(llvm::Loop *loop, llvm::Value *ptr,
        llvm::ScalarEvolution &se) {
    const llvm::SCEV *scev = se.getSCEV(ptr);
    auto *addrec = llvm::dyn_cast<llvm::SCEVAddRecExpr>(scev);
    if (!addrec || addrec->getLoop() != loop) return false;
    return !llvm::isa<llvm::SCEVConstant>(addrec->getStepRecurrence(se));
}

static bool forbid_gather_on_runtime_stride(llvm::Function &fn) {
    if (fn.isDeclaration() || fn.empty()) return false;
    llvm::TargetLibraryInfoImpl tlii(
        llvm::Triple(fn.getParent()->getTargetTriple()));
    llvm::TargetLibraryInfo tli(tlii);
    llvm::AssumptionCache ac(fn);
    llvm::DominatorTree dt(fn);
    llvm::LoopInfo li(dt);
    llvm::ScalarEvolution se(fn, tli, ac, dt, li);
    bool changed = false;
    for (llvm::Loop *loop : li.getLoopsInPreorder()) {
        bool copy = false;
        bool runtime_stride = false;
        bool arithmetic = false;
        for (llvm::BasicBlock *bb : loop->blocks()) {
            for (llvm::Instruction &inst : *bb) {
                if (inst.getOpcode() == llvm::Instruction::FAdd
                        || inst.getOpcode() == llvm::Instruction::FSub
                        || inst.getOpcode() == llvm::Instruction::FMul
                        || inst.getOpcode() == llvm::Instruction::FDiv
                        || inst.getOpcode() == llvm::Instruction::FRem) {
                    arithmetic = true;
                    continue;
                }
                auto *store = llvm::dyn_cast<llvm::StoreInst>(&inst);
                if (!store) continue;
                llvm::Value *stored = store->getValueOperand();
                if (auto *cast = llvm::dyn_cast<llvm::CastInst>(stored)) {
                    stored = cast->getOperand(0);
                }
                auto *load = llvm::dyn_cast<llvm::LoadInst>(stored);
                if (!load) continue;
                copy = true;
                if (is_runtime_step(loop, load->getPointerOperand(), se)
                        || is_runtime_step(loop, store->getPointerOperand(), se)) {
                    runtime_stride = true;
                }
            }
        }
        if (!copy || !runtime_stride || arithmetic) continue;
        llvm::addStringMetadataToLoop(loop, "llvm.loop.vectorize.enable", 0);
        changed = true;
    }
    return changed;
}

#if LLVM_VERSION_MAJOR < 17
struct ForbidGatherPass : public llvm::FunctionPass {
    static char ID;
    ForbidGatherPass() : llvm::FunctionPass(ID) {}
    bool runOnFunction(llvm::Function &fn) override {
        return forbid_gather_on_runtime_stride(fn);
    }
};
char ForbidGatherPass::ID = 0;
#else
struct ForbidGatherPass : llvm::PassInfoMixin<ForbidGatherPass> {
    llvm::PreservedAnalyses run(llvm::Function &fn,
            llvm::FunctionAnalysisManager &) {
        if (forbid_gather_on_runtime_stride(fn)) {
            return llvm::PreservedAnalyses::none();
        }
        return llvm::PreservedAnalyses::all();
    }
};
#endif

void LLVMEvaluator::opt(llvm::Module &m) {
    configure_module(m);
    disable_load_pre();
    reassociate_invariant_quotient(m);
    prepare_index_arithmetic(m);
    narrow_gather_indices(m);

#if LLVM_VERSION_MAJOR >= 17
    llvm::LoopAnalysisManager LAM;
    llvm::FunctionAnalysisManager FAM;
    llvm::CGSCCAnalysisManager CGAM;
    llvm::ModuleAnalysisManager MAM;
    // The default tuning options leave the SLP vectorizer off; clang and
    // flang enable it at -O2 and -O3, as the legacy pipeline below does.
    llvm::PipelineTuningOptions PTO;
    PTO.LoopVectorization = true;
    PTO.SLPVectorization = true;
    // Interleave is the vectorizer's own unroll. The default of 4 makes
    // a 4-wide body wait for 16 iterations, so a short runtime trip stays
    // scalar. One vector per iteration still vectorizes. Unrolling is a
    // separate pass and stays on.
    PTO.LoopInterleaving = false;
    llvm::PassBuilder PB = llvm::PassBuilder(TM.get(), PTO);
    PB.registerVectorizerStartEPCallback(
        [](llvm::FunctionPassManager &fpm, llvm::OptimizationLevel) {
            fpm.addPass(ForbidGatherPass());
        });
    PB.registerModuleAnalyses(MAM);
    PB.registerCGSCCAnalyses(CGAM);
    PB.registerFunctionAnalyses(FAM);
    PB.registerLoopAnalyses(LAM);
    PB.crossRegisterProxies(LAM, FAM, CGAM, MAM);
    llvm::ModulePassManager MPM = PB.buildPerModuleDefaultPipeline(llvm::OptimizationLevel::O3);
    // Late simplifications expose invariant conditions guarding descriptor loads.
    llvm::LoopPassManager LPM;
    LPM.addPass(llvm::SimpleLoopUnswitchPass(/*NonTrivial=*/true));
    LPM.addPass(llvm::LICMPass(llvm::LICMOptions()));
    MPM.addPass(llvm::createModuleToFunctionPassAdaptor(
        llvm::createFunctionToLoopPassAdaptor(std::move(LPM), /*UseMemorySSA=*/true)));
    MPM.run(m, MAM);

#else
#if LLVM_VERSION_MAJOR < 9
    disable_upper_bound_unrolling();
#endif
    llvm::legacy::PassManager mpm;
    mpm.add(new llvm::TargetLibraryInfoWrapperPass(TM->getTargetTriple()));
    mpm.add(llvm::createTargetTransformInfoWrapperPass(TM->getTargetIRAnalysis()));
    llvm::legacy::FunctionPassManager fpm(&m);
    fpm.add(llvm::createTargetTransformInfoWrapperPass(TM->getTargetIRAnalysis()));
    int optLevel = 3;
    int sizeLevel = 0;
    llvm::PassManagerBuilder builder;
    builder.OptLevel = optLevel;
    builder.SizeLevel = sizeLevel;
    builder.Inliner = llvm::createFunctionInliningPass(optLevel, sizeLevel,
        false);
    builder.DisableUnrollLoops = false;
    builder.LoopVectorize = true;
    builder.SLPVectorize = true;
    // createLoopVectorizePass(!LoopsInterleaved, ...) uses an interleave
    // count of 1 when this is false. The default count is 4 on x86, so
    // the vector body is skipped below 16 iterations.
    builder.LoopsInterleaved = false;
    builder.addExtension(llvm::PassManagerBuilder::EP_VectorizerStart,
        [](const llvm::PassManagerBuilder &,
           llvm::legacy::PassManagerBase &pm) {
            pm.add(new ForbidGatherPass());
        });
    builder.populateFunctionPassManager(fpm);
    builder.populateModulePassManager(mpm);
    fpm.doInitialization();
    for (llvm::Function &func : m) {
        fpm.run(func);
    }
    fpm.doFinalization();
    mpm.add(llvm::createVerifierPass());
    mpm.run(m);
#endif
    // The late cleanup and the horizontal reduction rewrite only run on
    // functions that the rewrite may apply to: definitions for x86 with AVX
    // that contain a vector whose lanes are sums of three squares. Other
    // functions and targets (such as AArch64) keep the code of the pipeline
    // above.
    std::vector<llvm::Function *> late_functions;
    for (llvm::Function &f : m) {
        if (may_recombine_horizontal_reductions(f, *TM)) {
            late_functions.push_back(&f);
        }
    }

    // SROA runs before the vectorizer, so a fixed-size local array that the
    // vectorized loop then accesses keeps its stack slot. Simplifying once
    // more promotes it and exposes the reductions the vectorizer built.
    // The loop passes after the last GVN also leave loads of memory that
    // was set from constants, such as the values a loop starts from; GVN
    // forwards them, so the horizontal reduction pass can see the
    // components that stay zero across the loop.
    if (!late_functions.empty()) {
#if LLVM_VERSION_MAJOR >= 17
        llvm::FunctionPassManager LateFPM;
        LateFPM.addPass(llvm::SROAPass(llvm::SROAOptions(
            llvm::SROAOptions::ModifyCFG)));
        LateFPM.addPass(llvm::GVNPass());
        LateFPM.addPass(llvm::InstCombinePass());
        LateFPM.addPass(llvm::SimplifyCFGPass());
        for (llvm::Function *f : late_functions) {
            LateFPM.run(*f, FAM);
        }
        // The functions changed outside of a module pass: drop the module
        // analyses (and through them the function ones) computed before.
        MAM.invalidate(m, llvm::PreservedAnalyses::none());
#else
        llvm::legacy::FunctionPassManager late(&m);
        late.add(llvm::createTargetTransformInfoWrapperPass(
            TM->getTargetIRAnalysis()));
        late.add(llvm::createSROAPass());
        late.add(llvm::createGVNPass());
        late.add(llvm::createInstructionCombiningPass());
        late.add(llvm::createCFGSimplificationPass());
        late.doInitialization();
        for (llvm::Function *f : late_functions) {
            late.run(*f);
        }
        late.doFinalization();
#endif
    }

    // The horizontal reduction pass finds the sums of squares of three
    // vector components that the SLP vectorizer builds, in whatever lane
    // layout, and rewrites them as pairwise horizontal additions. It only
    // matches fast math instructions, so ordinary compilations keep their
    // existing output.
    bool reduced = false;
    for (llvm::Function *f : late_functions) {
        reduced |= recombine_horizontal_reductions(*f, *TM);
    }
    if (reduced) {
        // Simplify and schedule the rewritten reductions. This is LLVM's
        // module O1 pipeline, so it also revisits functions the matcher
        // left unchanged.
#if LLVM_VERSION_MAJOR >= 17
        llvm::ModulePassManager Final
            = PB.buildPerModuleDefaultPipeline(llvm::OptimizationLevel::O1);
        Final.run(m, MAM);
#else
        llvm::legacy::PassManager final_mpm;
        final_mpm.add(new llvm::TargetLibraryInfoWrapperPass(
            TM->getTargetTriple()));
        final_mpm.add(llvm::createTargetTransformInfoWrapperPass(
            TM->getTargetIRAnalysis()));
        llvm::legacy::FunctionPassManager final_fpm(&m);
        final_fpm.add(llvm::createTargetTransformInfoWrapperPass(
            TM->getTargetIRAnalysis()));
        llvm::PassManagerBuilder final_builder;
        final_builder.OptLevel = 1;
        final_builder.SizeLevel = 0;
        final_builder.Inliner = llvm::createFunctionInliningPass(1, 0, false);
        final_builder.populateFunctionPassManager(final_fpm);
        final_builder.populateModulePassManager(final_mpm);
        final_fpm.doInitialization();
        for (llvm::Function &func : m) {
            final_fpm.run(func);
        }
        final_fpm.doFinalization();
        final_mpm.run(m);
#endif
    }

    // The Newton step of a reciprocal square root is written in IR, and IR
    // optimizations (InstCombine in recent LLVM) fold it back into a bare
    // 1/sqrt(x), which the code generator is then told to estimate without
    // refinement. So the expansion runs after every IR optimization.
    for (llvm::Function &f : m) {
        expand_reciprocal_sqrt(f, TM->getTargetTriple());
    }
    // llvm.exp.vNf64 survives as a vector intrinsic and the x86 backend then
    // calls scalar exp once per lane. glibc libmvec has the widened entry
    // points; use those instead.
    lower_vector_exp_to_libmvec(m);
    // 512 is an explicit request for the wide operations. Anything narrower
    // still has to split the SLP reductions the attribute does not stop.
    if (target_config.prefer_vector_width != 0
            && target_config.prefer_vector_width <= 256) {
        narrow_8wide_doubles(m);
    }
    // String temporaries for an untaken STOP/WRITE are allocated on entry
    // and freed on the way out, with no other use. malloc_alloc is not a
    // recognized malloc, so the pair survives -O3. d1mach pays for that on
    // every call.
    eliminate_unused_alloc_pairs(m);
    lower_avx512_scalar_fp_selects(m);
    for (llvm::Function &fn : m) {
        keep_negative_stride_off_fast_path(fn);
    }
    for (llvm::Function &fn : m) {
        if (fn.isDeclaration()) {
            continue;
        }
        unsigned width = 2;
        llvm::Triple triple(m.getTargetTriple());
        if (target_config.prefer_vector_width != 128
                && (triple.getArch() == llvm::Triple::x86
                    || triple.getArch() == llvm::Triple::x86_64)
                && TM->getSubtargetImpl(fn)->checkFeatures("+avx")) {
            // Four doubles fill a ymm register, which is the width
            // gfortran -march=native uses for this ordered reduction.
            width = 4;
        }
        bool again = true;
        while (again) {
            again = false;
            for (llvm::BasicBlock &bb : fn) {
                if (widen_strict_product_reduction(&bb, width)) {
                    again = true;
                    break;
                }
            }
        }
    }
}

std::string LLVMEvaluator::module_to_string(llvm::Module &m) {
    std::string buf;
    llvm::raw_string_ostream os(buf);
    m.print(os, nullptr);
    os.flush();
    return buf;
}

void LLVMEvaluator::print_version_message()
{
    llvm::cl::PrintVersionMessage();
}

std::string LLVMEvaluator::llvm_version()
{
    return LLVM_VERSION_STRING;
}

llvm::LLVMContext &LLVMEvaluator::get_context()
{
    return *context;
}

const llvm::DataLayout &LLVMEvaluator::get_jit_data_layout() {
    return jit->getDataLayout();
}

void LLVMEvaluator::print_targets()
{
    llvm::InitializeNativeTarget();
#ifdef HAVE_TARGET_AARCH64
    LLVMInitializeAArch64TargetInfo();
#endif
#ifdef HAVE_TARGET_X86
    LLVMInitializeX86TargetInfo();
#endif
#ifdef HAVE_TARGET_WASM
    LLVMInitializeWebAssemblyTargetInfo();
#endif
    llvm::raw_ostream &os = llvm::outs();
    llvm::TargetRegistry::printRegisteredTargetsForVersion(os);
}

std::string LLVMEvaluator::get_default_target_triple()
{
    return LLVMGetDefaultTargetTriple();
}

#ifdef __EMSCRIPTEN__

WasmLFortranExecutor::~WasmLFortranExecutor() = default;

WasmLFortranExecutor::WasmLFortranExecutor()
{
    LLVMInitializeWebAssemblyTarget();
    LLVMInitializeWebAssemblyTargetInfo();
    LLVMInitializeWebAssemblyTargetMC();
    LLVMInitializeWebAssemblyAsmPrinter();
    LLVMInitializeWebAssemblyAsmParser();

    context = std::make_unique<llvm::LLVMContext>();

    llvm::SmallString<256> tmp;
    if (llvm::sys::fs::createUniqueDirectory("xlfortran-wasm-exec-", tmp))
        throw LCompilersException("WasmLFortranExecutor: failed to create temp dir");
    TempDir = tmp.str().str();

    // Side modules share the process's dynamic-linker namespace.
    static std::atomic<int> s_next_id{0};
    m_id = s_next_id.fetch_add(1);
}

llvm::LLVMContext &WasmLFortranExecutor::get_context()
{
    return *context;
}

std::unique_ptr<LLVMModule> WasmLFortranExecutor::parse_module2(
    const std::string &source, const std::string &/*filename*/)
{
    llvm::SMDiagnostic err;
    auto mod = llvm::parseAssemblyString(source, err, *context);
    if (!mod)
        throw LCompilersException("WasmLFortranExecutor::parse_module2: Invalid LLVM IR: "
                                  + err.getMessage().str());
    return std::make_unique<LLVMModule>(std::move(mod));
}

void WasmLFortranExecutor::add_module(std::unique_ptr<LLVMModule> lm, int eval_count)
{
    std::unique_ptr<llvm::Module> mod = std::move(lm->m_m);

    const std::string instance = "__exec" + std::to_string(m_id) + "_";
    const std::string unique_stem = instance + std::to_string(eval_count);

    // Isolate every exported definition, not just cell entry points. Otherwise
    // a function in one executor can interpose on a variable in another. Record
    // ownership before renaming so imports from this and later modules agree,
    // while unresolved runtime imports retain their external ABI names.
    for (const llvm::GlobalValue &g : mod->global_values()) {
        if (!g.isDeclaration() && !g.hasLocalLinkage() && !g.hasAppendingLinkage()) {
            std::string name = g.getName().str();
            symbols.emplace(name, instance + name);
        }
    }
    for (llvm::GlobalValue &g : mod->global_values()) {
        auto symbol = symbols.find(g.getName().str());
        if (symbol != symbols.end()) g.setName(symbol->second);
    }

    const std::string triple = "wasm32-unknown-emscripten";
    std::string err;
#if LLVM_VERSION_MAJOR >= 21
    const llvm::Target *Target = llvm::TargetRegistry::lookupTarget(llvm::Triple(triple), err);
#else
    const llvm::Target *Target = llvm::TargetRegistry::lookupTarget(triple, err);
#endif
    if (!Target)
        throw LCompilersException("WasmLFortranExecutor: failed to find wasm32 target: " + err);

    llvm::TargetOptions TO;
    std::unique_ptr<llvm::TargetMachine> TM(
#if LLVM_VERSION_MAJOR >= 21
        Target->createTargetMachine(llvm::Triple(triple), "", "", TO, llvm::Reloc::Model::PIC_)
#else
        Target->createTargetMachine(triple, "", "", TO, llvm::Reloc::Model::PIC_)
#endif
    );
    mod->setTargetTriple(llvm::Triple(triple));
    mod->setDataLayout(TM->createDataLayout());

    llvm::SmallString<256> objFile, wasmFile;
    objFile = TempDir;
    llvm::sys::path::append(objFile, unique_stem + ".o");
    wasmFile = TempDir;
    llvm::sys::path::append(wasmFile, unique_stem + ".wasm");

    std::error_code EC;
    llvm::raw_fd_ostream ObjOut(objFile, EC);
    if (EC)
        throw LCompilersException("WasmLFortranExecutor: cannot open obj file: " + EC.message());

    llvm::legacy::PassManager PM;
    if (TM->addPassesToEmitFile(PM, ObjOut, nullptr, llvm::CodeGenFileType::ObjectFile))
        throw LCompilersException("WasmLFortranExecutor: wasm32 backend cannot emit object file");
    PM.run(*mod);
    ObjOut.close();

    std::vector<const char *> LinkerArgs = {
        "wasm-ld", "-shared",
        "--import-memory", "--experimental-pic", "--stack-first", "--allow-undefined",
        objFile.c_str(), "-o", wasmFile.c_str()
    };
    std::string lld_errs;
    llvm::raw_string_ostream lld_errs_stream(lld_errs);
    const ::lld::DriverDef WasmDriver = {::lld::Flavor::Wasm, &::lld::wasm::link};
    ::lld::Result Result = ::lld::lldMain(LinkerArgs, llvm::outs(), lld_errs_stream, {WasmDriver});
    if (Result.retCode)
        throw LCompilersException("WasmLFortranExecutor: wasm-ld failed for "
                                  + unique_stem + ": " + lld_errs_stream.str());

    void *handle = dlopen(wasmFile.c_str(), RTLD_NOW | RTLD_GLOBAL);
    if (!handle)
        throw LCompilersException(std::string("WasmLFortranExecutor: dlopen failed: ") + dlerror());
    (void)handle; // side module stays live for the process lifetime via RTLD_GLOBAL
}

intptr_t WasmLFortranExecutor::get_symbol_address(const std::string &name)
{
    auto symbol = symbols.find(name);
    const std::string &actual = symbol == symbols.end() ? name : symbol->second;

    void *sym = dlsym(RTLD_DEFAULT, actual.c_str());
    if (!sym)
        throw LCompilersException("WasmLFortranExecutor: symbol not found: " + name);
    return reinterpret_cast<intptr_t>(sym);
}

#endif // __EMSCRIPTEN__

} // namespace LCompilers
