struct t { int a; int b; };
int main() { struct t x; struct t y; y.a = 4; y.b = 2; return (x = y).a * 10 + (x = y).b + x.a * 100; }
