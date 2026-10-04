typedef int applier(int (*f)(int)); applier apply; int two(int a, int b) { return a + b; } int main(void) { return apply(two); }
