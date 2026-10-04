int two(int a, int b) { return a + b; } int apply(int (*f)(int)); int apply(); int main(void) { return apply(two); }
