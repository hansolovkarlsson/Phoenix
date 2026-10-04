int printf(const char *format, ...);
int puts();
long labs(long n);
long labs();
int twice();
int add(int a, int b);
int add();
int count, scale(), strcmp();
int main(void) {
    int small = -5;
    printf("%d %s %d %d\n", twice(21), "ok", add(2, 3), scale(4, 5));
    puts("line");
    printf("%d %d\n", strcmp("abc", "abd") < 0, strcmp("same", "same"));
    count = (int)labs(small);
    return count + twice(1);
}
int twice(int a) { return a * 2; }
int add(int a, int b) { return a + b; }
int scale(int a, int b) { return a * b + count; }
