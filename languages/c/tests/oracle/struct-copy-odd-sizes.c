struct c1 { char a; };
struct c3 { char a; char b; char c; };
struct c5 { int i; char c; };
int main() { struct c1 a; struct c1 b; struct c3 c; struct c3 d; struct c5 e; struct c5 f; a.a = 1; c.a = 2; c.b = 3; c.c = 4; e.i = 5; e.c = 6; b = a; d = c; f = e; return b.a + d.a * 2 + d.b * 3 + d.c * 4 + f.i * 5 + f.c * 6; }
