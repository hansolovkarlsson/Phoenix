int main() { int x = 1; int *p = &x; (*p) = 7; return (*&x) * 10 + *(&(x)); }
