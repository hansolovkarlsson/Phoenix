int bump(int *p) { *p = *p + 1; return 0; }
int main() { int x = 0; int n = sizeof bump(&x); return x * 10 + n; }
