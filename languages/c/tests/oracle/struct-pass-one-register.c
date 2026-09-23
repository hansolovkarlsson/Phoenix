struct c3 { char a; char b; char c; };
struct pt { int x; int y; };
int f(struct c3 c, struct pt p) { c.a = 0; return c.b * 1000 + c.c * 100 + p.x * 10 + p.y; }
int main() { struct c3 c; struct pt p; c.a = 1; c.b = 2; c.c = 3; p.x = 4; p.y = 5; return f(c, p) - 2000 + c.a; }
