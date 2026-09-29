int main(void) { int v = 1; const int *p = &v; *(1 ? p : p) = 2; return v; }
