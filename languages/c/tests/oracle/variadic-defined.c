int first(int n, ...) { return n; }
int putchar(int c);
int main() { putchar('0' + first(3, 4, 5)); putchar(10); return first(7) + first(8, "eight", 8, 8); }
