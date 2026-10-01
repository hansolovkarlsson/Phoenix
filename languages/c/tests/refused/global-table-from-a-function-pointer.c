int twice(int x) { return 2 * x; } int (*a)(int) = twice; int (*t[1])(int) = {a}; int main(void) { return t[0](1); }
