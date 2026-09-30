int printf(char *format, ...);
int primes[5] = {2, 3, 5, 7, 11};
long partial[4] = {9, 8};
int sized[] = {10, 20, 30};
char word[] = "hello";
char padded[8] = "hi";
char exact[2] = "hi";
static const char months[][4] = {"Jan", "Feb", "Mar"};
int grid[2][3] = {{1, 2, 3}, {4, 5, 6}};
int flat[2][2] = {1, 2, 3};
char *names[] = {"zero", "one", "two"};
int scalar = {42};
int total(int *a, int n) { int s = 0; for (int i = 0; i < n; i++) s += a[i]; return s; }
int kept(void) { static int counts[3] = {5, 6}; counts[2] += 1; return counts[0] + counts[1] + counts[2]; }
int main(void) {
    int local[4] = {1, 2, 3, 4};
    int some[5] = {7};
    int from[] = {total(primes, 5), (int)sizeof sized, local[3] * 10};
    char str[] = "abc";
    char buf[6] = "xy";
    int m[2][3] = {{1}, {4, 5}};
    int x = {5};
    kept();
    printf("%d %ld %ld %d %lu %lu %s %s %d %c\n", primes[4], partial[1], partial[3], sized[2], sizeof sized, sizeof word, word, padded, padded[7], exact[1]);
    printf("%s %s %lu %d %d %d %d %s %d\n", months[1], months[2], sizeof months, grid[1][2], flat[1][0], flat[1][1], total(local, 4), names[2], scalar);
    printf("%d %d %d %d %d %d %lu %s %d %d %d %d\n", some[0], some[4], from[0], from[1], from[2], x, sizeof str, str, buf[1], buf[5], m[0][1], m[1][1]);
    printf("%d %lu\n", kept(), sizeof(from));
    return some[0] + m[1][0];
}
