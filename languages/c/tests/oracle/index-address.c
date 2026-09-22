int main() {
    int a[3];
    int *p = &a[2];
    *p = 7;
    return a[2] * 10 + (&a[1] == a + 1) + (&a[0] == a);
}
