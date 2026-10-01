int twice(int x) { return 2 * x; } int (*a)(int) = twice; int (*b)(int) = a; int main(void) { return b(1); }
