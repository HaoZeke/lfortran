/* Minimal stubs for LAPACK routines - just enough to link and run.
   GFortran and LFortran call these as external procedures, so the
   symbol has one trailing underscore. The plain name is the same
   function for a caller that does not add one. */

int lsame_(void *a, void *b) { return 1; }
int lsame(void *a, void *b) { return lsame_(a, b); }

float slamch_(void *cmach) { return 1.0f; }
float slamch(void *cmach) { return slamch_(cmach); }

float slange_(void *norm, void *m, void *n, void *a, void *lda, void *work) { return 0.0f; }
float slange(void *norm, void *m, void *n, void *a, void *lda, void *work) {
    return slange_(norm, m, n, a, lda, work);
}

void sgemm_(void *transa, void *transb, void *m, void *n, void *k,
           void *alpha, void *a, void *lda, void *b, void *ldb,
           void *beta, void *c, void *ldc) {}
void sgemm(void *transa, void *transb, void *m, void *n, void *k,
           void *alpha, void *a, void *lda, void *b, void *ldb,
           void *beta, void *c, void *ldc) {
    sgemm_(transa, transb, m, n, k, alpha, a, lda, b, ldb, beta, c, ldc);
}

void slacpy_(void *uplo, void *m, void *n, void *a, void *lda, void *b, void *ldb) {}
void slacpy(void *uplo, void *m, void *n, void *a, void *lda, void *b, void *ldb) {
    slacpy_(uplo, m, n, a, lda, b, ldb);
}

void slascl_(void *type, void *kl, void *ku, void *cfrom, void *cto,
            void *m, void *n, void *a, void *lda, void *info) {}
void slascl(void *type, void *kl, void *ku, void *cfrom, void *cto,
            void *m, void *n, void *a, void *lda, void *info) {
    slascl_(type, kl, ku, cfrom, cto, m, n, a, lda, info);
}

void xerbla_(void *srname, void *info) {}
void xerbla(void *srname, void *info) { xerbla_(srname, info); }
