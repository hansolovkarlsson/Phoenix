struct acc { int n; int sum; int pad[4]; };
int walk(struct acc a) { if (a.n == 0) return a.sum; a.sum = a.sum + a.n; a.n = a.n - 1; return walk(a); }
int main() { struct acc a; a.n = 10; a.sum = 0; return walk(a) + a.sum; }
