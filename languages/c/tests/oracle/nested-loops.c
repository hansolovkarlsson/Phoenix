/* 0 + 1 + 2 + 3 + 4 iterations of the inner loop: 15. The labels of the
   inner loop must not be the outer ones. */
int main() {
    int c = 0;
    int i;
    int j;
    for (i = 0; i < 5; i = i + 1)
        for (j = 0; j <= i; j = j + 1)
            c = c + 1;
    return c;
}
