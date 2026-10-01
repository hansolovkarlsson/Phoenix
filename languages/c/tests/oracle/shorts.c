int printf(const char *format, ...);
struct packed { char c; short s; unsigned short u; };
short twice(short x) { return x * 2; }
int main(void) {
    short s = 32767;
    unsigned short u = 65535;
    short arr[4] = {1, -2, 300, -32768};
    short *p = arr;
    struct packed k = {'a', -7, 40000};
    s = s + 1;
    u = u + 1;
    printf("%d %d %d %d\n", s, u, arr[3], *(p + 2));
    printf("%d %d %d %d\n", (int)sizeof k, (int)sizeof arr, k.s, k.u);
    printf("%d %d\n", twice(20000), (short)70000);
    return arr[1] + 10;
}
