#include <lfortran/pipeline.h>

#include <chrono>
#include <fstream>

#include <libasr/asr_text.h>
#include <libasr/asr_utils.h>
#include <libasr/asr_verify.h>
#include <libasr/codegen/evaluator.h>
#include <libasr/config.h>

namespace LCompilers {

Result<ASR::TranslationUnit_t*> load_input_asr(
    const std::string &input, const std::string &infile, bool from_asr,
    Allocator &asr_text_allocator, FortranEvaluator &evaluator,
    LocationManager &lm, diag::Diagnostics &diagnostics,
    bool require_main_program)
{
    Result<ASR::TranslationUnit_t*> result =
        from_asr
        ? asr_from_text(asr_text_allocator, input, infile, lm, diagnostics)
        : evaluator.get_asr2(input, lm, diagnostics);
    if (!result.ok || !from_asr) {
        return result;
    }

    ASRVerifyOptions verify_options;
    verify_options.check_external = true;
    verify_options.require_main_program = require_main_program;
    if (!asr_verify(*result.result, verify_options, diagnostics)) {
        return Error();
    }
    return result;
}

ASRObjectResult compile_asr_to_object(
    ASR::TranslationUnit_t &asr, const std::string &infile,
    const std::string &outfile, bool assembly,
    CompilerOptions &compiler_options, PassManager &pass_manager,
    FortranEvaluator &evaluator, LocationManager &lm,
    diag::Diagnostics &diagnostics)
{
    ASRObjectResult result;
#ifndef HAVE_LFORTRAN_LLVM
    (void)asr;
    (void)infile;
    (void)outfile;
    (void)assembly;
    (void)compiler_options;
    (void)pass_manager;
    (void)evaluator;
    (void)lm;
    diagnostics.add(diag::Diagnostic(
        "LLVM is not enabled", diag::Level::Error,
        diag::Stage::CodeGen));
    result.phase = ASRPipelinePhase::PassesAndLLVM;
    result.status = 1;
    return result;
#else
    if (!pass_manager.has_user_defined_passes()) {
        pass_manager.use_default_passes();
    }
    if (compiler_options.emit_debug_info) {
#ifndef HAVE_RUNTIME_STACKTRACE
        // -g is DWARF. The stacktrace runtime is a separate feature: it
        // turns those line tables into a traceback. Without it, still emit
        // the debug info and skip only that hookup. A hard error here
        // rejects every f2py build that forwards -g.
        diagnostics.add(diag::Diagnostic(
            "The `runtime stacktrace` is not enabled, so -g will not print a "
            "traceback. Debug information is still emitted. Re-build LFortran "
            "with `-DWITH_RUNTIME_STACKTRACE=yes` for stack traces",
            diag::Level::Warning, diag::Stage::Semantic, {}));
#endif
    }

    Result<std::unique_ptr<LLVMModule>> llvm_result =
        evaluator.get_llvm3(asr, pass_manager, diagnostics, lm, infile,
            &result.optimization_time_us);
    if (!llvm_result.ok) {
        LCOMPILERS_ASSERT(diagnostics.has_error())
        result.phase = ASRPipelinePhase::PassesAndLLVM;
        result.status = 5;
        return result;
    }

    LLVMEvaluator &llvm_evaluator =
        evaluator.get_llvm_evaluator();
    if (assembly) {
        llvm_evaluator.save_asm_file(
            *(llvm_result.result->m_m), outfile);
    } else {
        auto start = std::chrono::high_resolution_clock::now();
        llvm_evaluator.save_object_file(
            *(llvm_result.result->m_m), outfile);
        auto end = std::chrono::high_resolution_clock::now();
        result.object_time_us =
            std::chrono::duration_cast<std::chrono::microseconds>(
                end - start).count();
    }

    if (compiler_options.gpu_backend == "cuda" &&
            !compiler_options.gpu_cuda_source.empty()) {
        std::ofstream cuda_sidecar(outfile + ".cuda.cu");
        cuda_sidecar << compiler_options.gpu_cuda_source;
    }

    result.ok = true;
    result.phase = ASRPipelinePhase::ObjectEmission;
    return result;
#endif
}

} // namespace LCompilers
