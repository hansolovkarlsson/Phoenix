int main() { int x = 1; int *p = &x; void *v = &x; return *(x ? p : v); }
