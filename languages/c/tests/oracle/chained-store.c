int main() { int x = 0; int y = 0; int *p = &x; int *q = &y; *p = *q = 4; return x + y; }
