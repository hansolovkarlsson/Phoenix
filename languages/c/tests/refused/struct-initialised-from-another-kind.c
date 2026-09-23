struct t { int a; int b; };
struct u { int a; int b; };
int main() { struct u y; y.a = 1; struct t x = y; return x.a; }
