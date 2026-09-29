int main(void) { int v = 1; const int *p = &v; *(0, p) = 2; return v; }
