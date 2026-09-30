int printf(const char *fmt, ...);
extern int counter;
int counter;
int counter = 3;
int tentative;
int tentative;
_Static_assert(sizeof(int) == 4, "int is four bytes");
int old(a, b)
    int a;
    long b;
{
    return a + (int)b;
}
int main(void) {
    extern int counter;
    _Static_assert(sizeof(long) == 8, "long is eight bytes");
    counter += old(4, 5L);
    printf("%d %d\n", counter, tentative);
    return counter;
}
