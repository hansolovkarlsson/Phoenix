typedef int T;
int count, printf(const char *format, ...), total = 5;
int twice(int), *where(void), last;
static int hidden(T T), kept;
long wide(long a, long b), *none(void);
T after = 7;
void *malloc(unsigned long size), *block;
static int hidden(T v) { return v + 1; }
int main(void) {
    int small = -100000;
    block = malloc(sizeof(long));
    *(long *)block = 41;
    count = twice(4);
    *where() += 1;
    kept = hidden(after);
    last = (int)(wide(small, 3) / 1000);
    printf("%d %d %d %d %d %d %ld\n", count, total, kept, last, after, none() == 0, *(long *)block + 1);
    return count + kept;
}
int twice(int a) { return a * 2; }
int *where(void) { return &count; }
long wide(long a, long b) { return a * b; }
long *none(void) { return 0; }
