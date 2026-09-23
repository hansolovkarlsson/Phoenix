struct t { int a; };
struct t f() { struct t s; s.a = 1; return s; }
int main() { int *p = &f().a; return *p; }
