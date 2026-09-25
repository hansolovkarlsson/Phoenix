int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n % 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
int main() {
    int i = -7; long three = 3; long big = 4294967298; long l = 10; int m = -3; char c = 100; int j = 5;
    i /= big; print(i);
    i = -7; i %= big; print(i);
    i = 3; i *= big; print(i);
    i = -7; i /= three; print(i);
    l += m; print(l);
    l -= m * 100000000; print(l);
    c += 100; print(c);
    c *= 3; print(c);
    c /= -2; print(c);
    print(c -= 100);
    j -= c; print(j);
    j %= 7; print(j);
    putchar(10);
    return (c += 200) + 1;
}
