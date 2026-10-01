int add(int a, int b) { return a + b; } int main(void) { int (*t[2])(int, int) = {add, add}; return t[i](1, 2); }
