int one(int a) { return a; } void *get(void) { return one; } int main(void) { return get() != 0; }
