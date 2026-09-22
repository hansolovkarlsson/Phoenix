int fill(int *p, int v) { *p = v; return 0; }
int main() { int a[5]; fill(a, 6); return *a * 10 + sizeof a / sizeof(int); }
