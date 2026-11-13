void greet_(int *n);

int main(void) {
    int n = 0;
    greet_(&n);
    return n == 4 ? 0 : 1;
}
