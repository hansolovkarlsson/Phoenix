int printf(char *format, ...);
typedef int T;
struct s { int a; };
int one(void) { struct t { char c; } x; x.c = 3; return (int)sizeof(x) + x.c; }
int two(void) { struct t { long l[2]; } y; y.l[1] = 5; return (int)sizeof(y) + (int)y.l[1]; }
int three(void) { struct s { char c[3]; } z; z.c[2] = 9; return (int)sizeof(z) + z.c[2]; }
int main(void) {
    struct s outer;
    int total = 0;
    outer.a = 7;
    {
        typedef long T;
        struct s;
        struct s *p;
        struct s { long big; long more; } v;
        v.big = 30;
        p = &v;
        total += (int)sizeof(T) + (int)p->big + (int)sizeof(*p);
    }
    total += (int)sizeof(T) + outer.a + one() + two() + three() + (int)sizeof(struct s);
    printf("%d %d %d\n", total, one(), two());
    return total;
}
