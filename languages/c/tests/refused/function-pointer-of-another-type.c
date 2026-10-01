int add(int a, int b) { return a + b; } int main(void) { long (*f)(long) = add; return f != 0; }
