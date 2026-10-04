int two(int a, int b) { return a + b; } int x, apply(int (*f)(int)); int main(void) { return apply(two); }
