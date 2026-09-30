int printf(char *format, ...);
struct later;
struct later *gp;
typedef struct fw *FP;
struct fw *make(void);
struct outer { int a; long pad; };
struct later { int w; long x; };
struct fw { char c; long v; };
struct fw pool[3];
struct fw *make(void) { return pool; }
struct outer outers[2];
int main(void) {
    struct later arr[3];
    FP q;
    int total;
    arr[0].w = 1; arr[1].w = 2; arr[2].w = 3;
    pool[0].v = 10; pool[1].v = 20; pool[2].v = 30;
    outers[0].a = 100; outers[1].a = 200;
    gp = arr;
    q = pool;
    total = (gp + 1)->w + gp[2].w + (int)(q + 2)->v + (int)make()[1].v;
    {
        struct outer *op = outers;
        struct outer { long b[4]; } inner;
        inner.b[3] = 7;
        total += (op + 1)->a + (int)inner.b[3] + (int)sizeof(inner) + (int)sizeof(*op);
    }
    printf("%d %ld %ld %ld\n", total, (long)((gp + 2) - gp), (long)sizeof(struct later), (long)sizeof(*q));
    return total % 256;
}
