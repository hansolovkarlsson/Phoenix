struct pt { int x; int y; };
struct big { int v[6]; };
int dot(struct pt a, struct pt b) { return a.x * b.x + a.y * b.y; }
int first(struct big b, int k) { return b.v[0] + k; }
int main() { struct pt a; struct pt b; struct big g; a.x = 2; a.y = 3; b.x = 4; b.y = 5; g.v[0] = 6; return first(g, dot(a, b)) + dot(b, a) + first(g, first(g, 1)); }
