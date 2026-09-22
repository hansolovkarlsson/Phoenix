int main() { int a[3]; *a = 1; *(a + 1) = 2; *(2 + a) = 3; return *(a + 1) * 10 + *(a + 2); }
