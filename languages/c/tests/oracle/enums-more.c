int printf(const char *format, ...);
enum { TOKF_BOL = 1u << 0, TOKF_SPACE = 1u << 1, TOKF_MACRO = 1u << 4 };
enum mode { OFF, ON = 10, AUTO, ALL = OFF | ON | AUTO | 16, NONE = ~0 };
typedef enum { PROEM_NOTE, PROEM_WARNING, PROEM_ERROR } proem_severity;
enum count { ZERO, ONE, TWO };
enum bases { HEXV = 0x1F, OCTV = 017, BIGHEX = 0x7FFFFFFF };
int weights[3] = {ONE * 10, TWO * 20, TWO + ONE};
struct token { int kind; unsigned flags; proem_severity sev; };
static proem_severity worst(proem_severity a, proem_severity b) { return a > b ? a : b; }
static const char *say(enum mode m) {
    switch (m) {
    case OFF: return "off";
    case ON: return "on";
    case AUTO: return "auto";
    case ALL: return "all";
    default: return "none";
    }
}
int main(void) {
    struct token t = {AUTO, TOKF_BOL | TOKF_MACRO, PROEM_WARNING};
    static enum count kept = TWO;
    enum count up = -1;
    enum mode down = -1;
    long wide = up;
    long narrow = down;
    int ONE = 100;
    {
        enum { ZERO = 7 } inner = ZERO;
        printf("%d %d %d\n", inner, ZERO, ONE);
    }
    printf("%d %u %d %d %d\n", t.kind, t.flags, t.flags & TOKF_SPACE, (t.flags & TOKF_MACRO) != 0, worst(t.sev, PROEM_ERROR));
    printf("%s %s %s %s %s\n", say(OFF), say(AUTO), say(ALL), say(NONE), say(down));
    printf("%d %d %d %d %d\n", weights[0], weights[1], weights[2], kept, ZERO);
    printf("%ld %ld %d %d %u\n", wide, narrow, up > 0, down < 0, up / 2);
    printf("%d %d %d\n", HEXV, OCTV, BIGHEX);
    return ALL + (int)sizeof(proem_severity);
}
