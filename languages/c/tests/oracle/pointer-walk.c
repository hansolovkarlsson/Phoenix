int main() {
    int a[4];
    int *p;
    int n = 0;
    for (p = a; p != a + 4; p = p + 1) { *p = n; n = n + 1; }
    p = p - 1;
    return *p * 10 + *(p - 3) + a[2];
}
