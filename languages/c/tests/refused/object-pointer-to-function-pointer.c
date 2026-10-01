int main(void) { int x = 0; int (*f)(int) = &x; return f != 0; }
