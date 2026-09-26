int printf(char *format, ...);
int first(int n, long k, ...);
int main() {
    printf("no arguments\n");
    printf("%% is not a conversion\n");
    return first(7, 8589934592);
}
int first(int n, long k, ...) { return n * 6 + k / 4294967296; }
