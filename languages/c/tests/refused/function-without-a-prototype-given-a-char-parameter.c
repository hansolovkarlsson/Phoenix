int g(char a) { return a; }
int main(void) { int (*h)() = g; return h(1); }
