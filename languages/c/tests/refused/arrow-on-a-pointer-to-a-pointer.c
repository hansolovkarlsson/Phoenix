struct t { int a; };
int main() { struct t *p; struct t **q; q = &p; return q->a; }
