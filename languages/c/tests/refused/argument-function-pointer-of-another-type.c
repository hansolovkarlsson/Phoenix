int two(int a, int b) { return a + b; } int apply(int (*f)(int), int x) { return f(x); } int main(void) { return apply(two, 1); }
