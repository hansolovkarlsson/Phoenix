int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
int main() {
    print(2147483647); print(2147483648); print(-2147483648); print(3000000000 - 1);
    print(sizeof(2147483647)); print(sizeof(2147483648)); print(sizeof(-2147483648));
    print(9000000000000000000); putchar(10); return 0;
}
