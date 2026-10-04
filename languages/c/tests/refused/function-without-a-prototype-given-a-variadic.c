int g(int a, ...) { return a; }
int (*h)() = g;
int main(void) { return 0; }
