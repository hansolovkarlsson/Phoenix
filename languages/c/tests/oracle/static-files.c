int printf(char *format, ...);
static int twice(int x);
static int errors;
static long base = 100;
static char *name = "static";
static int used[2];
static int twice(int x) { return 2 * x; }
struct pair { int a; int b; };
static struct pair *nowhere;
static void note(void) { errors++; }
static int *first(void) { return &used[0]; }
int main(void) {
    note(); note();
    *first() = 7;
    printf("%d %ld %s %d %d\n", twice(21), base + errors, name, used[0], nowhere == 0);
    return errors;
}
