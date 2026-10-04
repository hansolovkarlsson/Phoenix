int two(int a, int b) { return a + b; } int (*get(void))(int) { return two; } int main(void) { return get()(1); }
