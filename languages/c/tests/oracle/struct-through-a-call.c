int putchar(int c);
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct acc { int sum; int count; };
int add(struct acc *a, int v) { a->sum = a->sum + v; a->count = a->count + 1; return a->count; }
int main() {
    struct acc a; a.sum = 0; a.count = 0;
    add(&a, 5); add(&a, 7); print(add(&a, 30)); print(a.sum); putchar(10);
    return 0;
}
