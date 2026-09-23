struct t { int a; };
struct u { int a; };
struct t f() { struct u y; y.a = 1; return y; }
int main() { return f().a; }
