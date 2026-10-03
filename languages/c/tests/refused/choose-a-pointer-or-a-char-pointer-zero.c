int main() { int x = 1; int *p = &x; return *(x ? p : (char *)0); }
