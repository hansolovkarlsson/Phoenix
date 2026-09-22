int deep(int *p) { int **q = &p; **q = 7; return 0; }
int main() { int x = 1; deep(&x); return x; }
