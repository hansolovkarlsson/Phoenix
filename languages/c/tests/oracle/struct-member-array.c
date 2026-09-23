int putchar(int c);
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct buf { int len; char text[6]; int after; };
int main() {
    struct buf b; char *p; int i;
    b.len = 5; b.after = 99;
    for (i = 0; i < 5; i = i + 1) { b.text[i] = 'a' + i; }
    b.text[5] = 0;
    for (p = b.text; *p != 0; p = p + 1) { putchar(*p); }
    putchar(10);
    print(sizeof b.text); print(sizeof b); print(b.after); print(*(b.text + 2)); putchar(10);
    return 0;
}
