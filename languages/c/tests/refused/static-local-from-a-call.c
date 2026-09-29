int f(void) { return 1; } int main(void) { static int b = f(); return b; }
