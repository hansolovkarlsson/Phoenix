int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n % 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
int main() {
    long one = 1; long neg = -1099511627776; long three = 3; char c = -128; int k; int s = 0;
    print(one << 40); print(neg >> 20); print(-16 >> 2); print(c >> 1); print(5 << three);
    print(sizeof(1 << three)); print(sizeof(one << 1)); print(1 + 2 << 3); print(64 >> 1 + 1);
    for (k = 0; k < 5; k++) s = s + (1 << k);
    print(s); print(3 < 1 << 2);
    putchar(10);
    return s;
}
