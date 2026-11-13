#include <string.h>

void t1_(char *result, long result_len, char *value, long value_len);
void t5_(char *result, long result_len, char *value, long value_len);

int main(void) {
    char in1 = 'a';
    char out1 = 'x';
    char in5[5] = {'a', 'b', 'c', 'd', 'e'};
    char out5[5];
    t1_(&out1, 1, &in1, 1);
    if (out1 != 'a') return 1;
    memset(out5, 'x', 5);
    t5_(out5, 5, in5, 5);
    if (memcmp(out5, "abcde", 5) != 0) return 2;
    return 0;
}
