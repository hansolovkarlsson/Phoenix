int putchar(int c);
int digits(long n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(long n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
typedef long i64;
typedef long *i64p;
i64 sq(i64 x) { return x * x; }
int main() { i64 a = 3037000499; i64p p = &a; print(sq(*p)); print(sizeof(i64)); putchar(10); return 0; }
