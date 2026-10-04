int g(_Bool a) { return a; }
int main(void) { int (*h)() = 0; h = g; return 0; }
