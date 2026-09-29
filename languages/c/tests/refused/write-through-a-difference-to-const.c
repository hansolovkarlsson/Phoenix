int main(void) { int v[2]; const int *p = &v[1]; *(p - 1) = 2; return 0; }
