struct t { int a; int b; };
struct u { int a; int b; };
int f(struct t s);
int main() { struct u y; return f(y); }
