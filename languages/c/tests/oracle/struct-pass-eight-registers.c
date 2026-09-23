struct p4 { int a; int b; int c; int d; };
int f(int a, int b, int c, int d, int e, int g, struct p4 s) { return a + b + c + d + e + g + s.a + s.b * 2 + s.c * 3 + s.d * 4; }
int main() { struct p4 s; s.a = 1; s.b = 2; s.c = 3; s.d = 4; return f(1, 2, 3, 4, 5, 6, s); }
