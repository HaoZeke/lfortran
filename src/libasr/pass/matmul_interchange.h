#ifndef LIBASR_PASS_MATMUL_INTERCHANGE_H
#define LIBASR_PASS_MATMUL_INTERCHANGE_H

#include <libasr/asr.h>
#include <libasr/utils.h>

namespace LCompilers {

    // An ijk product that accumulates into a scalar, then stores it, is a
    // reduction along the strided index. Split it so the contiguous index is
    // the inner loop. Each output element is still summed in the original
    // order, so this does not need fast-math reassociation.
    void pass_matmul_interchange(Allocator &al, ASR::TranslationUnit_t &unit,
                                 const PassOptions &pass_options);

} // namespace LCompilers

#endif
