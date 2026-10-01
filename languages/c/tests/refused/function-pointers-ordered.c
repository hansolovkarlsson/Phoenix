int add(int a, int b) { return a + b; } int main(void) { int (*f)(int, int) = add; return f < add; }
