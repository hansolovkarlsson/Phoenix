int main() { int x = 2; int *p = &x; int *q = p; *q = *q + 5; return x; }
