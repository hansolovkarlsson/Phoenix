int main(void) { int v = 1; const int *p = &v; *p = 2; return v; }
