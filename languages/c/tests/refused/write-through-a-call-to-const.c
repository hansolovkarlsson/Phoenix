int v; const int *f(void) { return &v; } int main(void) { *f() = 2; return v; }
