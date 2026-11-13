#include <libasr/asr.h>
#include <libasr/asr_utils.h>
#include <libasr/pass/matmul_interchange.h>

namespace LCompilers {

// c(i, j) = sum_k a(i, k) * b(k, j), written as a scalar accumulator.
// a and c are contiguous in i (column-major, first index). Rewriting the
// i loop as the innermost one is a pointwise update, not a reassociation.

static ASR::symbol_t *var_symbol(ASR::expr_t *e) {
    if (e == nullptr || !ASR::is_a<ASR::Var_t>(*e)) {
        return nullptr;
    }
    return ASR::down_cast<ASR::Var_t>(e)->m_v;
}

static bool is_one(ASR::expr_t *e) {
    if (e == nullptr) {
        return true;
    }
    if (!ASR::is_a<ASR::IntegerConstant_t>(*e)) {
        return false;
    }
    return ASR::down_cast<ASR::IntegerConstant_t>(e)->m_n == 1;
}

static bool is_real_zero(ASR::expr_t *e) {
    if (e == nullptr || !ASR::is_a<ASR::RealConstant_t>(*e)) {
        return false;
    }
    return ASR::down_cast<ASR::RealConstant_t>(e)->m_r == 0.0;
}

static ASR::symbol_t *index_symbol(const ASR::ArrayItem_t &item, size_t dim) {
    if (dim >= item.n_args) {
        return nullptr;
    }
    if (item.m_args[dim].m_left != nullptr || item.m_args[dim].m_step != nullptr) {
        return nullptr;
    }
    return var_symbol(item.m_args[dim].m_right);
}

static ASR::expr_t *clone_item(Allocator &al, const ASR::ArrayItem_t &src) {
    Vec<ASR::array_index_t> args;
    args.reserve(al, src.n_args);
    for (size_t i = 0; i < src.n_args; i++) {
        args.push_back(al, src.m_args[i]);
    }
    return ASRUtils::EXPR(ASR::make_ArrayItem_t(al, src.base.base.loc,
        src.m_v, args.p, args.size(), src.m_type, src.m_storage_format,
        nullptr, src.m_in_bounds));
}

static ASR::stmt_t *assign(Allocator &al, const Location &loc,
        ASR::expr_t *target, ASR::expr_t *value) {
    return ASRUtils::STMT(ASRUtils::make_Assignment_t_util(
        al, loc, target, value, nullptr, false, false));
}

static ASR::stmt_t *do_loop(Allocator &al, const Location &loc,
        const ASR::do_loop_head_t &head, ASR::stmt_t *body) {
    Vec<ASR::stmt_t*> stmts;
    stmts.reserve(al, 1);
    stmts.push_back(al, body);
    return ASRUtils::STMT(ASRUtils::make_DoLoop_t_util(
        al, loc, nullptr, head, stmts.p, stmts.size(), nullptr, 0));
}

// `loop` is the loop over the contiguous index. On success, `zero_loop`
// clears the output and `k_loop` does the product with that index innermost.
static bool interchange(Allocator &al, const ASR::DoLoop_t &loop,
        ASR::stmt_t *&zero_loop, ASR::stmt_t *&k_loop) {
    if (loop.n_body != 3 || loop.n_orelse != 0 || !is_one(loop.m_head.m_increment)) {
        return false;
    }
    ASR::symbol_t *i_sym = var_symbol(loop.m_head.m_v);
    if (i_sym == nullptr) {
        return false;
    }
    if (!ASR::is_a<ASR::Assignment_t>(*loop.m_body[0])
            || !ASR::is_a<ASR::DoLoop_t>(*loop.m_body[1])
            || !ASR::is_a<ASR::Assignment_t>(*loop.m_body[2])) {
        return false;
    }
    ASR::Assignment_t *zero = ASR::down_cast<ASR::Assignment_t>(loop.m_body[0]);
    ASR::DoLoop_t *k_do = ASR::down_cast<ASR::DoLoop_t>(loop.m_body[1]);
    ASR::Assignment_t *store = ASR::down_cast<ASR::Assignment_t>(loop.m_body[2]);
    ASR::symbol_t *acc = var_symbol(zero->m_target);
    if (acc == nullptr || !is_real_zero(zero->m_value) || var_symbol(store->m_value) != acc) {
        return false;
    }
    if (k_do->n_body != 1 || k_do->n_orelse != 0 || !is_one(k_do->m_head.m_increment)) {
        return false;
    }
    ASR::symbol_t *k_sym = var_symbol(k_do->m_head.m_v);
    if (k_sym == nullptr || k_sym == i_sym || k_sym == acc) {
        return false;
    }
    if (!ASR::is_a<ASR::Assignment_t>(*k_do->m_body[0])) {
        return false;
    }
    ASR::Assignment_t *step = ASR::down_cast<ASR::Assignment_t>(k_do->m_body[0]);
    if (var_symbol(step->m_target) != acc || !ASR::is_a<ASR::RealBinOp_t>(*step->m_value)) {
        return false;
    }
    ASR::RealBinOp_t *add = ASR::down_cast<ASR::RealBinOp_t>(step->m_value);
    if (add->m_op != ASR::binopType::Add || var_symbol(add->m_left) != acc
            || !ASR::is_a<ASR::RealBinOp_t>(*add->m_right)) {
        return false;
    }
    ASR::RealBinOp_t *mul = ASR::down_cast<ASR::RealBinOp_t>(add->m_right);
    if (mul->m_op != ASR::binopType::Mul
            || !ASR::is_a<ASR::ArrayItem_t>(*mul->m_left)
            || !ASR::is_a<ASR::ArrayItem_t>(*mul->m_right)
            || !ASR::is_a<ASR::ArrayItem_t>(*store->m_target)) {
        return false;
    }
    ASR::ArrayItem_t *a = ASR::down_cast<ASR::ArrayItem_t>(mul->m_left);
    ASR::ArrayItem_t *b = ASR::down_cast<ASR::ArrayItem_t>(mul->m_right);
    ASR::ArrayItem_t *c = ASR::down_cast<ASR::ArrayItem_t>(store->m_target);
    if (a->m_storage_format != ASR::arraystorageType::ColMajor
            || c->m_storage_format != ASR::arraystorageType::ColMajor
            || a->n_args != 2 || b->n_args != 2 || c->n_args != 2) {
        return false;
    }
    // a(i, k), b(k, j), c(i, j): i is the contiguous index of a and c.
    if (index_symbol(*a, 0) != i_sym || index_symbol(*a, 1) != k_sym) {
        return false;
    }
    ASR::symbol_t *j_sym = index_symbol(*b, 1);
    if (index_symbol(*b, 0) != k_sym || j_sym == nullptr
            || j_sym == i_sym || j_sym == k_sym || j_sym == acc) {
        return false;
    }
    if (index_symbol(*c, 0) != i_sym || index_symbol(*c, 1) != j_sym) {
        return false;
    }

    const Location &loc = loop.base.base.loc;
    ASR::expr_t *c_zero = clone_item(al, *c);
    ASR::stmt_t *clear = assign(al, loc, c_zero, zero->m_value);
    zero_loop = do_loop(al, loc, loop.m_head, clear);

    ASR::expr_t *c_lhs = clone_item(al, *c);
    ASR::expr_t *c_rhs = clone_item(al, *c);
    ASR::expr_t *sum = ASRUtils::EXPR(ASR::make_RealBinOp_t(
        al, loc, c_rhs, ASR::binopType::Add, add->m_right, add->m_type, nullptr));
    ASR::stmt_t *update = assign(al, loc, c_lhs, sum);
    ASR::stmt_t *i_loop = do_loop(al, loc, loop.m_head, update);
    k_loop = do_loop(al, k_do->base.base.loc, k_do->m_head, i_loop);
    return true;
}

static void rewrite(Allocator &al, ASR::stmt_t **&body, size_t &n);

static void recurse(Allocator &al, ASR::stmt_t *stmt) {
    if (ASR::is_a<ASR::DoLoop_t>(*stmt)) {
        ASR::DoLoop_t *loop = ASR::down_cast<ASR::DoLoop_t>(stmt);
        rewrite(al, loop->m_body, loop->n_body);
    } else if (ASR::is_a<ASR::If_t>(*stmt)) {
        ASR::If_t *iff = ASR::down_cast<ASR::If_t>(stmt);
        rewrite(al, iff->m_body, iff->n_body);
        rewrite(al, iff->m_orelse, iff->n_orelse);
    } else if (ASR::is_a<ASR::WhileLoop_t>(*stmt)) {
        ASR::WhileLoop_t *w = ASR::down_cast<ASR::WhileLoop_t>(stmt);
        rewrite(al, w->m_body, w->n_body);
    }
}

static void rewrite(Allocator &al, ASR::stmt_t **&body, size_t &n) {
    Vec<ASR::stmt_t*> out;
    out.reserve(al, n);
    bool changed = false;
    for (size_t i = 0; i < n; i++) {
        ASR::stmt_t *zero_loop = nullptr;
        ASR::stmt_t *k_loop = nullptr;
        if (ASR::is_a<ASR::DoLoop_t>(*body[i])
                && interchange(al, *ASR::down_cast<ASR::DoLoop_t>(body[i]),
                    zero_loop, k_loop)) {
            out.push_back(al, zero_loop);
            out.push_back(al, k_loop);
            changed = true;
            continue;
        }
        out.push_back(al, body[i]);
        recurse(al, body[i]);
    }
    if (changed) {
        body = out.p;
        n = out.size();
    }
}

class MatmulInterchange : public ASR::BaseWalkVisitor<MatmulInterchange> {
public:
    Allocator &al;
    explicit MatmulInterchange(Allocator &al_) : al(al_) {}

    void visit_Function(const ASR::Function_t &x) {
        ASR::BaseWalkVisitor<MatmulInterchange>::visit_Function(x);
        ASR::Function_t &fn = const_cast<ASR::Function_t&>(x);
        rewrite(al, fn.m_body, fn.n_body);
    }

    void visit_Program(const ASR::Program_t &x) {
        ASR::BaseWalkVisitor<MatmulInterchange>::visit_Program(x);
        ASR::Program_t &prog = const_cast<ASR::Program_t&>(x);
        rewrite(al, prog.m_body, prog.n_body);
    }
};

void pass_matmul_interchange(Allocator &al, ASR::TranslationUnit_t &unit,
        const PassOptions &/*pass_options*/) {
    MatmulInterchange v(al);
    v.visit_TranslationUnit(unit);
}

} // namespace LCompilers
