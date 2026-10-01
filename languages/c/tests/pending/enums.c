int printf(const char *format, ...);
enum color { RED, GREEN = 5, BLUE, NONE = -1 };
typedef enum { SMALL = 1, LARGE = SMALL + 9 } size_e;
enum pos { FIRST, SECOND };
struct item { enum color c; size_e s; };
static const char *name(enum color c) {
    switch (c) {
    case RED: return "red";
    case GREEN: return "green";
    case BLUE: return "blue";
    default: return "none";
    }
}
int main(void) {
    enum color c = BLUE;
    size_e s = LARGE;
    enum pos up = -1;
    struct item it = {GREEN, SMALL};
    enum { LOCAL = 3 } l = LOCAL;
    int table[7] = {0};
    table[GREEN] = 9;
    table[BLUE] = table[GREEN] + BLUE;
    printf("%d %d %d %d %d\n", RED, GREEN, BLUE, NONE, s);
    printf("%s %s %s %d\n", name(c), name(it.c), name(NONE), (int)sizeof(enum color));
    printf("%d %d %d %d %d\n", it.s + l, table[5], table[BLUE], up < 0, FIRST - 1 < 0);
    return c + LOCAL;
}
