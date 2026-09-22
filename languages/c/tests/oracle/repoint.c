int main() { int x = 1; int y = 2; int *p = &x; p = &y; *p = 5; return x * 10 + y; }
