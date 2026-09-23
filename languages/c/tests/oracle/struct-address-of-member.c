struct pair { int a; int b; };
int set(int *p, int v) { *p = v; return 0; }
int main() { struct pair s; int *q; s.a = 1; s.b = 2; q = &s.b; *q = 40; set(&s.a, 2); return s.a + s.b; }
