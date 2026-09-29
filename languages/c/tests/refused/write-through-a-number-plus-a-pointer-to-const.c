int main(void) { int v[2]; const int *p = v; *(1 + p) = 2; return 0; }
