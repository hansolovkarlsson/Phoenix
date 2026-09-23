struct t { int a; int b; char c; };
int main() { struct t s; struct t u; s.a = 1; s.b = 2; s.c = 3; u = s; s.a = 10; s.b = 20; s.c = 30; struct t v = u; u.a = 100; return s.a + s.b + s.c + u.a + u.b + u.c + v.a; }
