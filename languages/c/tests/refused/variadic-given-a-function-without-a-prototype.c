int apply(int (*f)(int, ...)) { return f(1); }
int main(void) { int (*h)() = 0; return apply(h); }
