struct t { int a; int b; };
int main() { struct t s; struct t u; s.a = 1; u = s; return u.a; }
