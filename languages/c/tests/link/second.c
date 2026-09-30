static int count;
static int helper(void) { return 100; }
static int later(void);
int later(void) { return 5000; }
static long total = 1000;
static int seen[2];
static int both = 20;
extern int both;
static int also;
extern int also = 300;
int static placed = 300;
long static scale(long x) { return 3 * x; }
extern int shared;
int from_second(void) { extern int shared; shared += 2; count += helper(); total += later(); seen[1] += 1000; return count + total + seen[1] + placed + scale(1) + both + also; }
struct cell { int id; long weight; };
static struct cell cells[2];
struct cell *pick(void) { cells[1].id = 77; return cells; }
