int printf(char *format, ...);
int main(void) {
    int below = sizeof(int) - 5 < 0;
    long half = (sizeof(int) - 5) / 2;
    int top = (sizeof(int) - 5) >> 60;
    long rem = (sizeof(char) - 2) % 7;
    int n = -1;
    printf("%d %ld %d %ld %d\n", below, half, top, rem, n < sizeof(int));
    return below + top;
}
