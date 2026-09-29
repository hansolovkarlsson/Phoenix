int printf(char *format, ...);
int count(void) { static int n; n = n + 1; return n; }
int from(void) { static int n = 40; n += 1; return n; }
long deep(int k) { static long depth = 0; static long most; depth++; if (depth > most) most = depth;
                   if (k > 0) deep(k - 1); depth--; return most; }
int table[3];
int *slot(void) { static int *p = table; return p++; }
int *kept(void) { static int k = 9; static int *pk = &k; *pk += 1; return pk; }
char *greet(void) { static char *s = "hi"; return s; }
int sum(int x) { static int seen[4]; static unsigned char calls = 254; seen[x % 4] += x; calls++;
                 return seen[0] + seen[1] + seen[2] + seen[3] + calls; }
int main(void) {
    int a = count(); int b = count(); int c = from(); int d = from();
    int i;
    for (i = 0; i < 3; i++) *slot() = 10 * (i + 1);
    printf("%d %d %d %d\n", a, b, c, d);
    { long four = deep(4); long two = deep(2); printf("%ld %ld\n", four, two); }
    kept();
    printf("%d %d %d %s %d\n", table[0], table[1], table[2], greet(), *kept());
    { int s1 = sum(1); int s2 = sum(2); int s7 = sum(7); printf("%d %d %d\n", s1, s2, s7); }
    { static int n = 5; int k; n *= 2; k = count(); printf("%d %d\n", n, k); }
    { static int n = 7; n += 100; printf("%d\n", n); }
    return count() + from();
}
