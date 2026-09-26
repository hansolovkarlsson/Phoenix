int printf(char *format, ...);
int count;
int answer = 42;
char low = -3;
char high = 5;
long big = 4294967301;
char mark;
int table[4];
struct pt { int x; char y; };
struct pt origin;
int bump(void) { count++; return count; }
void fill(int n) { int i; for (i = 0; i < 4; i++) table[i] = n * i; }
void move(int x) { origin.x = x; }
int main(void) {
    printf("%d %d %d\n", count, origin.x, origin.y);
    bump(); bump(); fill(10); move(7); low = low - 1;
    printf("%d %d %d %ld %d\n", count, low, high, big, table[3]);
    { int answer = 1; printf("%d\n", answer); }
    printf("%d %ld\n", mark, (long)table % 4);
    return answer + origin.x + count;
}
