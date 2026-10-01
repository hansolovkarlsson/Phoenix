int printf(const char *format, ...);
struct mixed { char a; short b; char c; int d; short e[3]; };
short gs = -12345;
unsigned short gu = 65000;
short garr[5] = {1, [3] = -300, 7};
static short kept(short x) { static short total = 100; total += x; return total; }
int takes(short x) { return x; }
static const char *kind(int v) {
    switch (v) {
    case (short)70000: return "wrapped";
    case (unsigned short)-1: return "max";
    default: return "other";
    }
}
int main(void) {
    short s = 32767;
    unsigned short u = 0;
    short a[6] = {0, 1, 2, 3, 4, 5};
    short *p = &a[1];
    short *q = &a[5];
    struct mixed m = {'x', -2, 'y', 9, {10, 20, 30}};
    s++;
    u--;
    short w = 30000;
    w += 30000;
    printf("%d %d %d %d\n", s, u, w, (unsigned short)-1 > 0);
    printf("%d %d %d %d %d\n", (int)sizeof m, (int)(q - p), m.b + m.e[2], gs, gu);
    printf("%d %d %d %d\n", garr[0], garr[3], garr[4], garr[1]);
    printf("%d %d %s %s %hd\n", kept(5), kept(-205), kind(4464), kind(65535), s);
    int big = 70000;
    short t;
    unsigned short v;
    printf("%d %d\n", t = big, v = -big);
    return takes(big) % 256 + (u + u > 100000);
}
