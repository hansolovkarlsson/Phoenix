struct c3 { char a; char b; char c; };
struct p3 { int x; int y; int z; };
struct p4 { int w; int x; int y; int z; };
struct big { int v[6]; char t; };
int small(struct c3 c, int k) { return c.a + c.b * 2 + c.c * 3 + k * 1000; }
int pair(int k, struct p3 a, struct p4 b) { return k + a.x + a.y * 2 + a.z * 3 + b.w * 4 + b.x * 5 + b.y * 6 + b.z * 7; }
int large(struct big b, int k) { int s = 0; int i; for (i = 0; i < 6; i = i + 1) { s = s + b.v[i]; b.v[i] = 0; } b.t = 0; return s + k; }
int eight(int a, int b, int c, int d, int e, int f, struct p4 s) { return a + b + c + d + e + f + s.w + s.x * 2 + s.y * 3 + s.z * 4; }
