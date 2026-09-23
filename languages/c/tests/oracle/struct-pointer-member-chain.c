int putchar(int c);
int digits(int n) { if (n >= 10) digits(n / 10); putchar('0' + n - (n / 10) * 10); return 0; }
int print(int n) { if (n < 0) { putchar('-'); n = 0 - n; } digits(n); putchar(' '); return 0; }
struct node { int v; struct node *next; };
struct holder { struct node *head; int count; };
int main() {
    struct node a; struct node b; struct node c; struct holder h;
    a.v = 1; b.v = 2; c.v = 3; a.next = &b; b.next = &c; c.next = &a;
    h.head = &a; h.count = 3;
    print(h.head->next->next->v); print(h.head->next->next->next->next->v);
    h.head->next->v = 20; print(b.v); print((&h)->head->v); putchar(10);
    return 0;
}
