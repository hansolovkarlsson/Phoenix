int printf(const char *format, ...);
struct diag { void (*report)(void *ctx, int severity, const char *msg); void *ctx; };
struct named { const char *name; int (*fn)(int); };
int twice(int x) { return 2 * x; }
int square(int x) { return x * x; }
static const struct named table[] = {{"twice", twice}, {"square", square}};
static void count_reports(void *ctx, int severity, const char *msg) {
    int *n = ctx;
    *n += severity;
    printf("report %d: %s\n", severity, msg);
}
static void report(const struct diag *d, int severity, const char *msg) {
    if (d && d->report)
        d->report(d->ctx, severity, msg);
}
int main(void) {
    int count = 0;
    struct diag d = {count_reports, &count};
    struct diag quiet = {0, 0};
    struct diag later = {.ctx = &count, .report = count_reports};
    report(&d, 1, "first");
    report(&quiet, 5, "never");
    report(&later, 2, "second");
    report(0, 9, "nothing");
    int r = 0;
    for (int i = 0; i < 2; i++) r = r * 100 + table[i].fn(i + 3);
    printf("%s %d %d\n", table[1].name, r, count);
    return count;
}
