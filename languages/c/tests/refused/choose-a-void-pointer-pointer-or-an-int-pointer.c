int main() { int x = 1; int *p = &x; void **vv = 0; return (x ? vv : p) == 0; }
