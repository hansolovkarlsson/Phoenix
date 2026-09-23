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
    return 0;
}
