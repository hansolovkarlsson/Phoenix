int printf(const char *fmt, ...);
struct later;
struct node { int v; struct node *next; struct later *other; };
struct later { int w; };
typedef struct { int x, y; } point;
struct outer { struct inner { int k; } in; int z; } global, *gptr;
int main(void) {
    struct local { int q; } l;
    typedef long wide;
    wide w = 40;
    struct later lt;
    struct node n2, n1;
    point pt;
    struct inner in;
    l.q = 1; lt.w = 2; n2.v = 3; n1.v = 4; n1.next = &n2; n1.other = &lt;
    pt.x = 5; pt.y = 6; global.in.k = 7; global.z = 8; gptr = &global; in.k = 9;
    {
        struct local { long big; } shadow;
        shadow.big = 10;
        printf("%ld %lu\n", shadow.big, sizeof(struct local));
    }
    printf("%d %d %d %d %d %d\n", l.q, n1.next->v, n1.other->w, pt.x + pt.y, gptr->in.k, in.k);
    printf("%ld %lu %lu\n", w, sizeof(struct local), sizeof(struct outer));
    return global.z;
}
