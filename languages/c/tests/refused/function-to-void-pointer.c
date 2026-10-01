int add(int a, int b) { return a + b; } int main(void) { void *p = add; return p != 0; }
