struct t { int a; char c; int *p; };
int main() { struct t s; int x; x = 5; s.a = s.c = 11; s.p = &x; *s.p = s.a + s.c; return x; }
