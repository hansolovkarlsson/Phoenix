int main() { int x = 1; int *p = &x; return *(x ? p : (const void *)0); }
