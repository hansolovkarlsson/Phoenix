int putchar(int c);
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct node { int v; struct node *next; };
int main() {
    struct node n[5]; struct node *p; int i; int sum;
    for (i = 0; i < 5; i = i + 1) { n[i].v = i * i; n[i].next = &n[i] + 1; }
    n[4].next = 0;
    sum = 0;
    for (p = &n[0]; p != 0; p = p->next) { print(p->v); sum = sum + p->v; }
    print(sum); print(n[0].next->next->next->v); putchar(10);
    return 0;
}
