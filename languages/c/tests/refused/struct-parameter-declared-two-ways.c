struct t { int a; int b; };
struct u { int a; int b; };
int f(struct t s);
int f(struct u s) { return s.a; }
int main() { return 0; }
