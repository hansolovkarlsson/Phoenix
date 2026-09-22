int main() { int x = 1; int *p = &x; int **q = &p; return sizeof *p * 10 + sizeof *q; }
