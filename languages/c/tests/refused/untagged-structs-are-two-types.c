int main(void) { struct { int a; } x; struct { int a; } y; x.a = 1; y = x; return y.a; }
