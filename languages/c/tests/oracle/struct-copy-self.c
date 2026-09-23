struct t { int a[5]; };
int main() { struct t s; int i; for (i = 0; i < 5; i = i + 1) s.a[i] = i + 1; s = s; return s.a[0] + s.a[4] * 10; }
