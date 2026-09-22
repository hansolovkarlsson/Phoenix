int main() { int x = 1; int *p = &x; int **q = &p; **q = 9; return x; }
