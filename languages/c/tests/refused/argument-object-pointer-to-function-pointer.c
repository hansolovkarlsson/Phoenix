int apply(int (*f)(int)) { return f(1); } int main(void) { int x = 0; return apply(&x); }
