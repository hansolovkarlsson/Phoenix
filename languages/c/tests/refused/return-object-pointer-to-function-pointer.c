int x; int (*get(void))(int) { return &x; } int main(void) { return get() != 0; }
