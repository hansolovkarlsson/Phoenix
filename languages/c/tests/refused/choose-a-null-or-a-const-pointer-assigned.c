int main() { int x = 1; const int *p = &x; *(x ? 0 : p) = 2; return x; }
