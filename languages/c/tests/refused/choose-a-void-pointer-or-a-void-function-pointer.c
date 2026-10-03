void g(void) {}
int main() { int x = 1; void *v = &x; void (*gp)(void) = g; return (x ? v : gp) == 0; }
