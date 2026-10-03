int putchar(int c);
struct t { int a; int b; };
enum { NONE, ONE };
int twice(int n) { return n * 2; }
char *name(int c) { return c ? "2" : ((void *)0); }
int *found(int has, int *id) { return has ? id : ((void *)0); }
int main() {
    int x = 3; int y = 0; int a[2]; struct t s; char *q; int (*f)(int); int r = 0;
    a[0] = 7; a[1] = 9; s.a = 1; s.b = 40;
    r = r + *(x ? a : 0) + (y ? 0 : a)[1];
    r = r + (found(y, a) == 0) + *found(x, a + 1);
    q = name(x); putchar(q[0]); r = r + (name(y) == 0) * 2;
    r = r + (x ? &s : (void *)0)->b + (y ? (void *)0 : &s)->a;
    r = r + sizeof(x ? a : 0) + sizeof(y ? 0L : &s) * 10;
    r = r + *(x ? a : 1 - 1) + *(x ? a : NONE) + ((y ? a : 0) == 0) * 100;
    r = r + ((x ? (void *)0 : 0 * 5 + (2 - 2)) == 0) + ((y ? 0 : (void *)0) == 0) * 2;
    f = x ? twice : 0; r = r + f(5) + ((y ? twice : 0) == 0) * 3;
    f = y ? 0 : x ? 0 : twice; r = r + (f == 0) * 4;
    r = r + (y ? 0 : twice)(6) + ((x ? (void *)0 : twice) == 0);
    putchar(10);
    return r % 256;
}
