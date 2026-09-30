int printf(char *format, ...);
struct wide { long a, b, c; };
struct wide make(int seed) {
    int pad[100];
    struct wide w;
    pad[99] = seed;
    w.a = pad[99]; w.b = seed * 2; w.c = seed * 3;
    return w;
}
int sum(int first, int second) {
    int buffer[90];
    int after = first + second;
    buffer[0] = after;
    long late = buffer[0] * 2;
    return (int)late + after;
}
int main(void) {
    char text[300];
    int count = 7;
    long total = 0;
    struct wide w = make(5);
    text[299] = 'z';
    for (int i = 0; i < count; i++) total += i;
    printf("%d %ld %c %ld %ld %ld %d\n", count, total, text[299], w.a, w.b, w.c, sum(2, 3));
    return (int)total;
}
