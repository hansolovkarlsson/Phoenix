int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n % 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
int main() {
    long big = 6442450943; int m = -2; char c = -128; int a = 12;
    print(big & m); print(big | 1); print(big ^ m); print(~big); print(~c); print(~0);
    print(a & 10 == 10); print((a & 10) == 8); print(a | 1 ^ 3 & 6); print(-1 & 255);
    putchar(10);
    return ~a & 255;
}
