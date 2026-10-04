/* A function declared in a block, alone, in a list with a local, and
 * through a typedef of its type, C11 6.7.6.3, and a parameter of a
 * function's type, which is a pointer to one, 6.7.6.3p8. The locals
 * declared around each keep their own slots. */
int printf(const char *, ...);
typedef int binop(int, int);
typedef long lop(long);
typedef void say(void);
int said;
int apply(binop f, int x) { return f(x, x + 1); }
long wide(lop g, int x) { return g(x); }
long neg(long a) { return -a; }
int main(void) {
    int a = 1;
    int three(void);
    int b = 2;
    int x = 4, add(int, int);
    long long llabs(long long);
    binop mul;
    extern binop sub;
    say hush;
    int c = 3;
    hush();
    {
        int strcmp(const char *, const char *), d = 5;
        printf("%d %d %d %d %d\n", a, b, c, d, strcmp("a", "b") < 0);
    }
    printf("%d %d %d %d %lld\n", three(), add(x, 1), mul(2, 3), sub(9, 1), llabs(-7));
    {
        lop labs;
        printf("%ld %ld\n", labs(-x), labs(-5000000000));
    }
    printf("%d %ld %d\n", apply(add, 2), wide(neg, -3), (int)sizeof(binop *));
    return a + b + c + said;
}
int three(void) { return 3; }
int add(int a, int b) { return a + b; }
int mul(int a, int b) { return a * b; }
int sub(int a, int b) { return a - b; }
void hush(void) { said = 10; }
