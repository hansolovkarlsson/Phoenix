struct p { int x; int y; };
struct big { int v[7]; };
struct p later(int k);
struct big larger(int k);
int main() { struct p a = later(6); return a.x + a.y + larger(2).v[6]; }
struct p later(int k) { struct p r; r.x = k; r.y = k * 10; return r; }
struct big larger(int k) { struct big b; b.v[6] = k * 9; return b; }
