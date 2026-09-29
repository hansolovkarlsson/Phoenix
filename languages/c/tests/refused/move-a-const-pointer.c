int main(void) { int v = 1; int w = 2; int *const p = &v; p = &w; return *p; }
