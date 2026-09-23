int putchar(int c);
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct p { int x; int y; int z; };
int main() {
    struct p a[4]; int i;
    for (i = 0; i < 4; i = i + 1) { a[i].x = i; a[i].y = i * 10; a[i].z = i * 100; }
    for (i = 0; i < 4; i = i + 1) { print(a[i].x + a[i].y + a[i].z); }
    print(sizeof a); print(sizeof a[1]); putchar(10);
    return 0;
}
