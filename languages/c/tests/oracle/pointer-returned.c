int *second(int *p) { return p + 1; }
int main() { int a[2]; a[0] = 4; a[1] = 9; return *second(a) + *second(a - 1); }
