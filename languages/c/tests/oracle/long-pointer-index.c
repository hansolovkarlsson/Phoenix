int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
int main() {
    long a[4]; long *p; long i; int j; long neg = -1;
    a[0] = 5000000000; a[1] = -6; a[2] = 7; a[3] = 8;
    p = &a[2]; i = 1; j = -2;
    print(p[neg]); print(p[i]); print(*(p + j)); print(*(a + i)); print(p - a); print(a - p);
    print(sizeof a); print(sizeof(long)); print(sizeof(long *)); print(a[0] + a[3]); putchar(10); return 0;
}
