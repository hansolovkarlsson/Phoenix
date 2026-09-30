int printf(char *format, ...);
int typedef count_t;
unsigned typedef long size_type;
const typedef char *text;
count_t typedef tally_t;
struct pair { int a; long b; };
struct pair typedef pair_t;
struct pair static kept;
int static hidden = 7;
unsigned static long wide = 4000000000;
long int const limit = 12;
int long static twice(int long x) { return 2 * x; }
int unsigned static bump(void) { unsigned char static c = 250; c += 3; return c; }
int static calls(void) { int static n; const static int step = 2; n += step; return n; }
int kept_three(void) { count_t static a; static count_t b = 10; struct pair static p; pair_t static q; tally_t t = 1;
    a += 1; b += 2; p.a += 3; q.b += 4; return a + b + p.a + (int)q.b + t; }
int regsum(register int a, int register b) { register int s = a + b; return s; }
int main(void) {
    long int li = -2;
    int long il = 3;
    unsigned long int uli = 5;
    long unsigned lu = 6;
    int unsigned iu = 4000000000;
    signed long int sli = -7;
    int signed is = -8;
    signed si = -9;
    char signed cs = -10;
    char unsigned cu = 250;
    const long unsigned int const clu = 11;
    auto int au = 12;
    int auto ia = 13;
    register long rl = 14;
    long register lr = 15;
    count_t n = 16;
    size_type st = 17;
    text t = "eighteen";
    count_t const cn = 19;
    count_t register rn = 20;
    kept.a = 21; kept.b = 22;
    calls(); calls(); kept_three();
    printf("%ld %ld %lu %lu %u %ld %d %d %d %u\n", li, il, uli, lu, iu, sli, is, si, cs, cu);
    printf("%lu %d %d %ld %ld %d %lu %s %d %d\n", clu, au, ia, rl, lr, n, st, t, cn, rn);
    printf("%d %ld %d %lu %ld %ld %u %d %d\n", kept.a, kept.b, hidden, wide, limit, twice(il), bump(), calls(), regsum(3, 4));
    printf("%lu %lu %lu %lu\n", sizeof(long int), sizeof(int long unsigned), sizeof(char signed), sizeof(size_type));
    printf("%ld %u %d %d\n", (long int)-1, (int unsigned)3000000000u, (char signed)200, kept_three());
    return (int)(li + il + uli);
}
