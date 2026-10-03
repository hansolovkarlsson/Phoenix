int f(int x) { return x; }
int main() { int x = 1; void *v = &x; int (*fp)(int) = f; return (x ? v : fp) == 0; }
