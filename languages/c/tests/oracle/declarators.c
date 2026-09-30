int printf(const char *fmt, ...);
int add(int, int);
long int g1 = 5, g2, *gp;
int static hidden = 7;
int add(int a, int b) { return a + b; }
int main(void) {
    int a = 1, b, *p = &a;
    long int li = 2;
    int long il = 3;
    unsigned long int uli = 4;
    long unsigned lu = 5;
    int unsigned iu = 6;
    signed long int sli = -7;
    register int r = 8;
    auto int au = 9;
    int s = 0;
    b = 10;
    gp = &g1;
    for (int i = 0, j = 10; i < 3; i++, j--) s += i * j;
    printf("%d %d %d %ld %ld %ld %lu %lu %u %ld\n", a, b, *p, li, il, g2, uli, lu, iu, sli);
    printf("%d %d %d %ld %d %d\n", r, au, s, *gp, hidden, add(20, 22));
    return a + b;
}
