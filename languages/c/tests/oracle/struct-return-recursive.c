struct fib { int a; int b; };
struct big { int v[8]; };
struct fib step(int n) {
    struct fib f; int t;
    if (n == 0) { f.a = 0; f.b = 1; return f; }
    f = step(n - 1);
    t = f.a + f.b; f.a = f.b; f.b = t;
    return f;
}
struct big count(int n) {
    struct big b; int i;
    if (n == 0) { for (i = 0; i < 8; i = i + 1) b.v[i] = 0; return b; }
    b = count(n - 1);
    b.v[n - (n / 8) * 8] = b.v[n - (n / 8) * 8] + n;
    return b;
}
int main() { struct big b = count(20); return step(11).a + b.v[0] + b.v[3] * 2 + b.v[7]; }
