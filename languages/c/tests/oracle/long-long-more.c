int printf(const char *format, ...);
struct rec { char tag; long long v; };
long long table[3] = {1LL, -2ll, 0x7fffffffffffffffLL};
static unsigned long long mask = 0xFFFFFFFFFFFFFFFFULL;
static const char *size_of(long long x) {
    switch (x) {
    case 4294967296LL: return "big";
    case -1ll: return "minus";
    case 7uLL: return "seven";
    default: return "other";
    }
}
int main(void) {
    struct rec r = {'x', 5000000000LL};
    long long *p = table;
    unsigned long long int u = 10LLU;
    long long int narrow = 4294967297LL;
    signed char s[3] = {(signed char)255, 127, -128};
    printf("%d %d %lld %lld\n", (int)sizeof r, (int)sizeof(unsigned long long int), *(p + 2), r.v);
    printf("%s %s %s %s\n", size_of(4294967296LL), size_of(-1), size_of(7), size_of(8));
    printf("%llu %llu %d %d %d %d\n", mask, u * 3, (int)narrow, s[0], s[1] + s[2], s[0] < s[1]);
    return (int)(table[1] + 60);
}
