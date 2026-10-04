typedef int binop(int, int); int main(void) { int add = 1; { binop add; return add(1, 2); } }
