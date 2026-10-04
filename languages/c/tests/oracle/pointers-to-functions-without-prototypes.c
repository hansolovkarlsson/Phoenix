/* () in a pointer to a function is no prototype, C11 6.7.6.3p14, and
 * such a pointer is compatible with a function of any parameters whose
 * types are their own promotions and that has no '...', 6.7.6.3p15. A
 * call through one passes each argument in a register. Through a typedef
 * it declares a function a prototype before it still describes. */
int printf(const char *, ...);
int strcmp();
long labs(long);
typedef int F();
typedef long G();
F add;
F mul;
int mul(int a, int b);
F sub;
int y, sub(int a, int b);
F *fp;
G labs;
int add(int a, int b) { return a + b; }
int mul(int a, int b) { return a * b; }
int sub(int a, int b) { return a - b; }
int twice(int a) { return 2 * a; }
long sum(long a, long b) { return a + b; }
int none(void) { return 7; }
struct s { int x; };
int field(struct s v) { return v.x; }
int (*table[3])() = { twice, none, add };
int apply(int (*f)(), int x) { return f(x); }
int (*pick(int n))() { return n ? add : twice; }
int main(void) {
    static int (*sp)() = twice;
    int (*f)() = none;
    long (*g)() = sum;
    int (*p)(int, int) = (int (*)())add;
    int (*u)() = p;
    int (*k)() = field;
    int (*c)() = strcmp;
    struct s v = { 11 };
    fp = add;
    printf("%d %d %d %d %ld %d\n", f(), table[0](3), table[1](), table[2](4, 5), g(40L, 2L), apply(twice, 4));
    printf("%d %d %d %d %d %ld %d\n", fp(1, 2), pick(1)(3, 4), pick(0)(5), p(6, 7), u(8, 9), labs(-5), c("b", "a"));
    printf("%d %d %d\n", mul(6, 7), sub(9, 4), sp(21));
    k = 0;
    return k == 0 ? field(v) : 0;
}
