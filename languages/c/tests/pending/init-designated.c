int printf(char *format, ...);
struct token { int kind; int flags; const char *spelling; long len; };
static const struct token eof = {.kind = 9, .flags = 2, .spelling = ""};
int sparse[6] = {[1] = 10, [4] = 40, 50};
struct token later = {.flags = 3, "x", 1};
struct outer { struct token t; int n[3]; };
struct outer deep = {.t.kind = 5, .n[2] = 7, .t.len = 4};
int main(void) {
    struct token t = {.kind = 1, .spelling = "id", .len = 2};
    int a[5] = {[3] = 3, [1] = 1};
    struct token list[3] = {[2] = {.kind = 7}, [0].flags = 4};
    printf("%d %d %s %ld %d %d %s\n", t.kind, t.flags, t.spelling, t.len, eof.kind, eof.flags, eof.spelling);
    printf("%d %d %d %d %d %d\n", sparse[0], sparse[1], sparse[4], sparse[5], a[1], a[3]);
    printf("%d %s %ld %d %d %d %d %ld\n", later.flags, later.spelling, later.len, list[2].kind, list[0].flags, deep.t.kind, deep.n[2], deep.t.len);
    return t.kind + a[3];
}
