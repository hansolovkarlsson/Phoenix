static int count;
static int helper(void) { return 100; }
static int later(void);
int later(void) { return 5000; }
static long total = 1000;
static int seen[2];
int static placed = 300;
long static scale(long x) { return 3 * x; }
int from_second(void) { count += helper(); total += later(); seen[1] += 1000; return count + total + seen[1] + placed + scale(1); }
