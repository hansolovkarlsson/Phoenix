int main() { int x = 1; int y = 0; int *p = &x; return *(x ? p : y); }
