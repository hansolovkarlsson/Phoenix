int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
int main() {
    long l = 4294967297; int n = l; long m = 4294967295; int k; int c;
    print(n); k = m; print(k); c = 0;
    if (k = l) c = 1; print(c); print(k = l); print(n = m);
    l = 4294967296; if (k = l) c = c + 10; print(c);
    putchar(10); return 0;
}
