struct t { int a; int b; };
int main() { struct t x; struct t y; y.a = 1; y.b = 2; (x = y).a = 5; return x.a * 10 + y.a; }
