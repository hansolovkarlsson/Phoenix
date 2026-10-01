int main(void) { int (*f)(int, int); long (*g)(long) = 0; f = g; return f != 0; }
