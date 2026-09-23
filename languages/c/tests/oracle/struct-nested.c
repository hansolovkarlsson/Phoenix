int putchar(int c);
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct in { int x; char c; };
struct out { char tag; struct in a; struct in b; int last; };
int main() {
    struct out o;
    o.tag = 1; o.a.x = 20; o.a.c = 3; o.b.x = 40; o.b.c = 5; o.last = 6;
    print(o.tag); print(o.a.x); print(o.a.c); print(o.b.x); print(o.b.c); print(o.last);
    print(sizeof o.a); print(sizeof o); putchar(10);
    return 0;
}
