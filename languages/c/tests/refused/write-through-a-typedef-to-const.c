typedef const int cint; int main(void) { int v = 1; cint *p = &v; *p = 2; return v; }
