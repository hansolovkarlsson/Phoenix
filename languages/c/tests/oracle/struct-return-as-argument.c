struct p { int x; int y; };
struct big { int v[6]; };
struct p pt(int x, int y) { struct p r; r.x = x; r.y = y; return r; }
struct big fill(int k) { struct big b; int i; for (i = 0; i < 6; i = i + 1) b.v[i] = k + i; return b; }
int sum(struct p a, struct big b, struct p c) { return a.x + a.y * 2 + b.v[0] + b.v[5] * 3 + c.x * 4 + c.y * 5; }
struct p add(struct p a, struct p b) { struct p r; r.x = a.x + b.x; r.y = a.y + b.y; return r; }
struct big same(struct big b) { return b; }
int main() { return sum(pt(1, 2), same(fill(3)), add(pt(1, 1), add(pt(2, 3), pt(4, 5)))); }
