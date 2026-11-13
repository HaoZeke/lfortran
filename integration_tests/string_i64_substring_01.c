#include <stdint.h>
#include <sys/mman.h>

void i64_substr_scalar_(char *s, int64_t *n, int *last, long len);
void i64_substr_array_(char *a, int *m, int64_t *n, int *last, long len);

int main(void) {
    char small[4] = {'a', 'b', 'c', 'd'};
    int64_t n = 4;
    int m = 1;
    int last = 0;
    const int64_t big = (int64_t)2147483647 + 1;
    char *buf;

    i64_substr_scalar_(small, &n, &last, 4);
    if (last != 'd') return 1;
    last = 0;
    i64_substr_array_(small, &m, &n, &last, 4);
    if (last != 'd') return 2;

    buf = mmap(0, (size_t)big, PROT_READ | PROT_WRITE,
        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (buf == MAP_FAILED) return 3;
    buf[0] = 'a';
    buf[big - 1] = 'z';
    n = big;
    last = 0;
    i64_substr_scalar_(buf, &n, &last, (long)big);
    if (last != 'z') return 4;
    m = 1;
    last = 0;
    i64_substr_array_(buf, &m, &n, &last, (long)big);
    if (last != 'z') return 5;
    return 0;
}
