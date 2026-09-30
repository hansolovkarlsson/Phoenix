int printf(char *format, ...);
static int count;
static int helper(void) { return 1; }
static int later(void);
int later(void) { return 3; }
static long total = 10;
static int seen[2];
static int both = 1;
extern int both;
static int also;
extern int also = 3;
int static placed = 2;
long static scale(long x) { return 2 * x; }
int shared;
int shared = 40;
int from_second(void);
struct cell *pick(void);
struct cell { int id; long weight; };
int bump_first(void) { count++; total += helper() + later(); seen[1] += 7; return count; }
int main(void) {
    bump_first(); bump_first(); from_second();
    printf("%d %ld %d %d %d %ld\n", count, total, from_second(), seen[1], placed, scale(5));
    printf("%d %d %d %d\n", shared, both, also, (pick() + 1)->id);
    return count;
}
