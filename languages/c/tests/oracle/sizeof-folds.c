int printf(char *format, ...);
unsigned long twice = sizeof(int) * 2;
long spare = sizeof(long) - sizeof(int);
int wide = sizeof(int) < sizeof(long);
int main(void) {
    long n = 4;
    int r = 0;
    switch (n) {
    case sizeof(long) - 4: r = r + 1;
    case sizeof(long) / 2 + 1: r = r + 10; break;
    case (sizeof(int) << 3) >> 1: r = r + 100;
    }
    printf("%lu %ld %d %d %d\n", twice, spare, wide, r, sizeof r - 5 < 0);
    return r + (int)(sizeof(char) - 2 < 0);
}
