/* A '*' in parentheses inside another's, int (*(*p)) being int (**p):
 * in a global, a member, a typedef, a local and a static local, each
 * with and without a value, around a pointer to a function and to an
 * array, with a const on the inner star, three deep, and a typedef's
 * name hidden by one. */
int printf(const char *, ...);
typedef int T;
int g(void) { return 7; }
int (*gfp)(void) = g;
int x = 3, *px = &x;
int (*(*gp)) = &px;
int (*(*gz));
int (*(*(*gq))) = &gp;
int (*(*gf))(void);
int (*(*gfi))(void) = &gfp;
struct s { int (*(*m)); int (*(*mf))(void); int n; };
typedef int (*(*PP));
typedef int (*(*PF))(void);
int main(void) {
    int (*(*p)) = &px;
    int (*(* const (*q))) = &p;
    int (*(*f))(void);
    int (*(fp))(void) = g;
    int (*(*fi))(void) = &fp;
    int (*(*a))[2];
    int arr[2] = {4, 5};
    int (*w)[2] = &arr;
    static int (*(*sp)) = &px;
    static int (*(*sz));
    static int (*(*sf))(void);
    static int (*(*sfi))(void) = &gfp;
    PP pp = &px;
    PF pf = &fp;
    T (*(*T)) = &px;
    a = &w; gz = &px; sz = &px; sf = &gfp;
    struct s v; v.m = &px; v.mf = &fp; v.n = 1;
    f = &fp; gf = &fp;
    printf("%d %d %d %d %d %d %d\n", **p, ***q, (*f)(), (*gf)(), (*(*a))[1], ***gq, **v.m);
    printf("%d %d %d %d %d\n", (int)sizeof(p), (int)sizeof(*p), (int)sizeof(**p), **sp, **pp);
    printf("%d %d %d %d %d %d\n", (*fi)(), (*gfi)(), (*v.mf)(), (*pf)(), (*sf)(), (*sfi)());
    printf("%d %d %d %d\n", **T, (int)sizeof(PP), **gz, **sz);
    printf("%d %d %d\n", (int)sizeof(*gfi), (int)sizeof(*sfi), (int)sizeof(*pf));
    return **gp + v.n;
}
