int printf(char *format, ...);
int product = 6 * 7;
char wrapped = (char)300;
long wide = 4294967296 * 2;
struct pt { int x; char y; };
long size = sizeof(struct pt);
int negative = -2147483647 - 1;
int chosen = 3 > 2 ? 'a' : 'b';
char plain = 200;
int narrowed = 4294967301;
long minus = -3;
int main(void) {
    printf("%d %d %ld %ld %d %d\n", product, wrapped, wide, size, negative, chosen);
    printf("%d %d %ld\n", plain, narrowed, minus);
    printf("%ld %ld\n", (long)&wide % 8, (long)&narrowed % 4);
    return product + wrapped;
}
