int putchar(int c);
struct c3 { char a; char b; char c; };
struct p3 { int x; int y; int z; };
struct p4 { int w; int x; int y; int z; };
struct big { int v[6]; char t; };
int small(struct c3 c, int k);
int pair(int k, struct p3 a, struct p4 b);
int large(struct big b, int k);
int eight(int a, int b, int c, int d, int e, int f, struct p4 s);
struct c3 mk3(int k);
struct p3 mkp3(int k);
struct p4 mkp4(int k);
struct big mkbig(int k);
struct pl { long a; int b; };
long lmul(long a, int b);
int lnarrow(long x);
long lwiden(int x);
struct pl mkpl(long a, int b);
long sumpl(struct pl p);
int ldigits(long n) { if (n >= 10) ldigits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int lprint(long n) { if (n < 0) { putchar('-'); n = 0 - n; } ldigits(n); putchar(' '); return 0; }
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
int main() {
    struct c3 c; struct p3 a; struct p4 b; struct big g; int i;
    c.a = 1; c.b = 2; c.c = 3; a.x = 4; a.y = 5; a.z = 6; b.w = 7; b.x = 8; b.y = 9; b.z = 10;
    for (i = 0; i < 6; i = i + 1) g.v[i] = i + 1; g.t = 'k';
    print(small(c, 7)); print(pair(11, a, b)); print(large(g, 5)); print(large(g, 6));
    print(eight(1, 2, 3, 4, 5, 6, b)); print(g.v[0] + g.v[5]); putchar(g.t); putchar(10);
    c = mk3(4); print(c.a + c.b * 10 + c.c * 100); print(mkp3(3).z); a = mkp3(5); print(a.x + a.y + a.z);
    b = mkp4(2); print(b.w + b.x * 2 + b.y * 3 + b.z * 4); g = mkbig(7); print(g.v[0] + g.v[5] * 2); putchar(g.t);
    print(large(mkbig(1), 0)); putchar(10);
    lprint(lmul(-3, 4)); lprint(lmul(3000000000, -2)); print(lnarrow(4294967298)); print(lnarrow(-1));
    lprint(lwiden(-9)); lprint(mkpl(-5000000000, 3).a); print(mkpl(1, -7).b);
    lprint(sumpl(mkpl(-5000000000, 3))); putchar(10);
    if (lnarrow(4294967296)) putchar('?'); else putchar('.');
    print(!lnarrow(4294967296)); print(lnarrow(4294967296) || 0); print(lnarrow(4294967297) && 1);
    for (i = 0; i < 3 && lnarrow(4294967296 + i); i = i + 1) putchar('!'); print(i); putchar(10);
    return 0;
}
