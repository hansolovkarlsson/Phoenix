int printf(const char *format, ...);
struct id { unsigned long long dev, ino; };
long long mix(long long a, int b) { return a * b; }
int main(void) {
    long long big = 9000000000LL;
    unsigned long long top = 18446744073709551615ULL;
    long long int neg = -5ll;
    signed char sc = (signed char)200;
    unsigned char uc = 200;
    struct id f = {1, 2};
    printf("%lld %llu %lld %lld\n", big * 2, top, neg * big, mix(big, -3));
    printf("%d %d %d %d\n", sc, uc, sc < 0, (int)sizeof(long long) + (int)sizeof sc);
    printf("%llu %d\n", f.dev + f.ino, top > big);
    return (int)(big % 251);
}
