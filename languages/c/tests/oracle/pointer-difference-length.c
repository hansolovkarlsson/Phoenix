int length(int *s) { int *p = s; while (*p != 0) p = p + 1; return p - s; }
int main() { int a[6]; a[0] = 9; a[1] = 8; a[2] = 7; a[3] = 6; a[4] = 0; return length(a) * 10 + length(a + 2); }
