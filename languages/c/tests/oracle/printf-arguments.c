int printf(char *format, ...);
int main() {
    long big = 4294967301; int m = -2; char c = 'A'; char *s = "ok";
    printf("%d %ld %c %s %%\n", m, big, c, s);
    printf("%d %d %d %d %d %d %d %d %d %d\n", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
    printf("%ld %d\n", big - 5, m);
    printf("no arguments\n");
    return printf("%d\n", -1);
}
