int main() { int x = 1; int *p = &x; return *(x ? p : 0); }
