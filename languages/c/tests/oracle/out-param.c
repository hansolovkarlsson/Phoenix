int set(int *p, int v) { *p = v; return 0; }
int main() { int x = 1; set(&x, 42); return x; }
