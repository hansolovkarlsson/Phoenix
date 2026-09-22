int main() { int a[4]; int d = a - &a[3]; return (d < 0) * 100 + (a - &a[3] == 0 - 3) * 10 + d + 3; }
