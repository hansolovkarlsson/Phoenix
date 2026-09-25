struct t { int a; int b; };
struct t *pick(struct t *p, int i) { return p + i; }
int main() { struct t s[3]; s[2].b = 41; pick(s, 1)->a = 1; return pick(s, 2)->b + s[1].a; }
