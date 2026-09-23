struct t { int a; int b; };
struct u { int a; int b; };
int main() { struct t x; struct u y; y.a = 1; x = y; return x.a; }
