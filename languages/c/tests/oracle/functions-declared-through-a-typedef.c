int printf(const char *format, ...);
typedef int binop(int, int);
typedef long lop(long, long);
typedef int *getter(void);
typedef void *alloc(unsigned long size);
typedef long absolute(long n);
binop add, sub;
static binop mul;
lop wide;
getter where;
alloc malloc;
absolute labs;
binop add;
int stored;
int main(void) {
    int small = -100000;
    long *block = malloc(sizeof(long));
    *block = 41;
    *where() = add(2, 3) * mul(2, 2) - sub(9, 4);
    printf("%d %d %ld %ld %ld\n", add(1, 2), stored, wide(small, 3) / 1000, *block + 1, labs(small));
    return stored;
}
int add(int a, int b) { return a + b; }
int sub(int a, int b) { return a - b; }
static int mul(int a, int b) { return a * b; }
long wide(long a, long b) { return a * b; }
int *where(void) { return &stored; }
