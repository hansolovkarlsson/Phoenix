int main() { int x = 1; char c = 2; int *p = &x; char *q = &c; return *(x ? p : q); }
