int putchar(int c);
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct one { int a; };
struct pair { int a; int b; };
struct ci { char c; int i; };
struct ic { int i; char c; };
struct cc { char a; char b; };
struct cp { char c; int *p; };
struct ccc { char a[3]; };
struct cci { char a[5]; int i; };
struct nest { char c; struct ci in; };
struct list { int v; struct list *next; };
int main() {
    print(sizeof(struct one)); print(sizeof(struct pair)); print(sizeof(struct ci));
    print(sizeof(struct ic)); print(sizeof(struct cc)); print(sizeof(struct cp));
    print(sizeof(struct ccc)); print(sizeof(struct cci)); print(sizeof(struct nest));
    print(sizeof(struct list)); print(sizeof(struct list *)); putchar(10);
    return 0;
}
