int add(int a, int b) { return a + b; } int (*g)(int) = add; int main(void) { return g != 0; }
