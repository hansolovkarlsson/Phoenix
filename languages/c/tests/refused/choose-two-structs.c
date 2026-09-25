struct t { int a; };
struct u { int a; };
int main() { struct t s; struct u v; int x = 1; s.a = 1; v.a = 2; return (x ? s : v).a; }
