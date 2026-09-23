struct t { int a; };
int f();
struct t f() { struct t s; s.a = 1; return s; }
int main() { return 0; }
