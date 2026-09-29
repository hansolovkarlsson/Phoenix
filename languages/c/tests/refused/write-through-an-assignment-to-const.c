int main(void) { int v = 1; const int *p; *(p = &v) = 2; return v; }
