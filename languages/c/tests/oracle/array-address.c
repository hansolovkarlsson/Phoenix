int main() { int a[4]; int *p = &*a; *p = 9; return *a * 10 + sizeof &*a; }
