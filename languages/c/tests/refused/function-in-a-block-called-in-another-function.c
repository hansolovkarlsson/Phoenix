int g(void) { int f(void); return f(); } int h(void) { return f(); } int f(void) { return 3; } int main(void) { return g() + h(); }
