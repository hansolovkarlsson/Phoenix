struct t { int a; int b; };
int main() { struct t x; struct t y; int *p; y.a = 1; p = &(x = y).a; return 0; }
