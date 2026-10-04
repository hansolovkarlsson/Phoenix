int one(int a) { return a; } int deref(int *p) { return *p; } int main(void) { return deref(one); }
