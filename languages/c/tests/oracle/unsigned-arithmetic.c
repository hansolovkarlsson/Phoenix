int printf(char *format, ...);
unsigned int wrap(unsigned int a) { return a + 1; }
long widen(long n) { return n; }
long give(unsigned int u) { return u; }
struct bytes { unsigned char low; char high; unsigned long all; };
int main(void) {
    unsigned int big = (unsigned int)4294967295; unsigned int u = 7; int m = -2;
    unsigned char c = 200; unsigned long ul = 0; char sc = -56;
    long widened = big;
    unsigned char *pc = &c; struct bytes b; unsigned int h = big; unsigned int k = 3;
    int table[4]; int *row = table;
    ul = ul - 1;
    printf("%u %u %u %u\n", wrap(big), big / 2, (unsigned int)-8 >> 1, big % 10);
    printf("%d %d %d %u\n", m < u, -1 < (unsigned int)1, m + u > 0, m + u);
    printf("%d %d %d %ld\n", c, c + 1, (unsigned char)sc, widened);
    printf("%lu %lu %d\n", ul, ul / 3, ul > 1);
    b.low = 250; b.high = -6; b.all = ul; h /= 2; h >>= 1;
    table[3] = 33;
    printf("%d %d %d %lu %u\n", *pc, b.low, b.high, b.all >> 60, h);
    printf("%ld %ld %d %d\n", widen(big), give(big), row[k], (unsigned long)m > ul - 2);
    {
        long lw; long acc = 0; unsigned char small = 100;
        lw = big; acc += big;
        printf("%ld %ld %d %ld %ld %ld\n", big + (long)1, (long)big, big < (long)1,
               1 ? big : (long)0, lw, acc);
        printf("%d %d\n", (b.low = 456), (small += 100));
        {
            unsigned int t = big; t >>= 4;
            printf("%ld %u %ld %d\n", (long)1 + big, t, (long)-8 / u, c - 201 < 0);
        }
    }
    switch (big) { case 0: printf("zero\n"); break; default: printf("big\n"); }
    return c + (unsigned char)300;
}
