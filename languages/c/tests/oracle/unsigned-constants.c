int printf(char *format, ...);
int main(void) {
    unsigned int u = 3000000000u;
    printf("%d %d %d %ld\n", 0x10, 017, 0x7fffffff, 0x100000000);
    printf("%u %lu %ld %lu\n", 0xffffffff, 18446744073709551615ul, 10L, 0xFFFFFFFFFFFFFFFFUL);
    printf("%d %d\n", 0xffffffff > 0, -1 < 0xffffffff);
    switch (u) { case 3000000000u: printf("big\n"); break; case 0xB2D05E00u + 1: break; }
    switch (u / 1000000000) { case 3u: printf("three\n"); }
    return 0x2a;
}
