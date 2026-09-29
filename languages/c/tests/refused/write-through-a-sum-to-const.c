int main(void) { int v[2]; const int *p = v; *(p + 1) = 2; return 0; }
