struct t { int a; };
int f(struct t s) { s.a = s.a + 1; return s.a; }
int main() { struct t u; u.a = 41; return f(u) * 2 - u.a; }
