int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
int main() {
    int i = -5; long l = 3000000000; long x = i; int k = 7;
    print(l + i); print(i * l); print(x); print(l / i); print(k - l);
    print(i < l); print(l < i); print(x == i); print(-l); print(-i); putchar(10); return 0;
}
