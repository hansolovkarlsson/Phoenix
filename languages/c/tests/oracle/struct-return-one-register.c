struct c3 { char a; char b; char c; };
struct p2 { int x; int y; };
struct c3 three(int k) { struct c3 c; c.a = k; c.b = k + 1; c.c = k + 2; return c; }
struct p2 two(int x, int y) { struct p2 p; p.x = x; p.y = y; return p; }
int main() { struct c3 c = three(5); struct p2 p; p = two(30, 40); return c.a + c.b * 2 + c.c * 3 + p.x + p.y * 2; }
