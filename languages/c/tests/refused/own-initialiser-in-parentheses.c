int main(void) { int (*f)(void) = sizeof f > 4 ? 0 : 0; return f == 0; }
