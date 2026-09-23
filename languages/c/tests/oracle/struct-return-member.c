struct p { int x; int y; };
struct big { int v[5]; };
struct p pt(int x, int y) { struct p r; r.x = x; r.y = y; return r; }
struct big fill(int k) { struct big b; int i; for (i = 0; i < 5; i = i + 1) b.v[i] = k * i; return b; }
int main() { return pt(3, 4).y * 10 + fill(2).v[4] + sizeof pt(1, 2) + sizeof(fill(1)); }
