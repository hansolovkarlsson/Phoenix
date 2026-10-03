int f(int x) { return x; }
int main() { int x = 1; void *v = &x; return (x ? v : f) == 0; }
