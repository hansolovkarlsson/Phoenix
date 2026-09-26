int printf(char *format, ...);
int show(long n) { printf("<%ld>", n); return n / 1000000000; }
int main() {
    int k = printf("%d %d %d\n", 1, show(4294967296), 3);
    return k;
}
