int printf(char *format, ...);
static int count;
static int helper(void) { return 1; }
static int later(void);
int later(void) { return 3; }
static long total = 10;
static int seen[2];
int from_second(void);
int bump_first(void) { count++; total += helper() + later(); seen[1] += 7; return count; }
int main(void) {
    bump_first(); bump_first(); from_second();
    printf("%d %ld %d %d\n", count, total, from_second(), seen[1]);
    return count;
}
