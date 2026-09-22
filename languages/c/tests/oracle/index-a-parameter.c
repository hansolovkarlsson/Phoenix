int sum(int *p, int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i = i + 1) s = s + p[i];
    return s;
}
int main() { int a[4]; a[0] = 1; a[1] = 2; a[2] = 3; a[3] = 4; return sum(a, 4) * 10 + sum(a + 2, 2); }
