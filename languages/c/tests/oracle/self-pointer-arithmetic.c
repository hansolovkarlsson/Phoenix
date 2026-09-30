int printf(char *format, ...);
struct node { int v; struct node *next; };
int main(void) {
    struct node a[3];
    struct node *p = a;
    a[0].v = 1; a[1].v = 2; a[2].v = 3;
    p->next = a;
    printf("%d %d %ld\n", (p->next + 1)->v, (p->next)[2].v, (p->next + 2) - p->next);
    return (p->next + 1)->v;
}
