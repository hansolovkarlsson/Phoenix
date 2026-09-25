int **deeper(int **pp) { return pp; }
int *pass(int *p) { return p; }
int main() { int x; int *p; x = 12; p = &x; **deeper(&p) = 50; return *pass(p) + x; }
