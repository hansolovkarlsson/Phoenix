struct node { int v; struct node *next; };
typedef struct node node;
typedef node *list;
int sum(list l) { int s = 0; for (; l != 0; l = l->next) s = s + l->v; return s; }
int main() {
    node n[4]; list l; int i;
    for (i = 0; i < 4; i = i + 1) { n[i].v = i + 1; n[i].next = &n[i] + 1; }
    n[3].next = 0;
    l = &n[0];
    return sum(l) * 10 + sum(l->next->next);
}
