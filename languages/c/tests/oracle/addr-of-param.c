int bump(int n) { int *p = &n; *p = n + 1; return n; }
int main() { return bump(41); }
