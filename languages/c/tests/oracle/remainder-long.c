int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n % 10); return 0; }
int main() {
    long big = 3000000000; long neg = 0 - big; int i = -7; char c = -100;
    digits(big % 1000000007); putchar(' ');
    digits(0 - neg % 7); putchar(' ');
    digits(big % i); putchar(' ');
    digits(i % big + 10); putchar(' ');
    digits(c % 7 + 10); putchar(10);
    return neg % 256 + 256;
}
