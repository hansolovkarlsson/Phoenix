typedef int binop(int, int); int main(void) { { binop add; } return add(1, 2); } int add(int a, int b) { return a + b; }
