int putchar(int c);
int show(int n) { if (n < 0) { putchar('-'); n = 0 - n; } putchar('0' + n); putchar(' '); return 0; }
int main() {
    show(7 % 3); show(-7 % 3); show(7 % -3); show(-7 % -3); show(6 % 3); show(-6 % 3);
    show(2 % 5); show(-2 % 5); putchar(10);
    return (-7 / 2) * 2 + -7 % 2 + 7;
}
