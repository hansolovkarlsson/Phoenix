struct pt { int x; int y; };
struct seg { struct pt a; struct pt b; };
int len(struct pt p) { return p.x + p.y; }
int both(struct seg s) { return len(s.a) * 10 + len(s.b); }
int main() { struct seg s[2]; struct seg *p = &s[1]; s[1].a.x = 1; s[1].a.y = 2; s[1].b.x = 3; s[1].b.y = 4; return both(*p) + len(p->b) * 100 + both(s[1]); }
