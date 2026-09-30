int printf(char *format, ...);
typedef int row[3];
unsigned char bytes[4] = {250, 1, 255};
char signs[3] = {-1, 'a', -128};
long big[2] = {5000000000, -7};
int g1 = 11, g2 = 22;
int *gp[2] = {&g1, &g2};
row groww = {7, 8, 9};
int a3[3] = {1, 2, 3}, b3[3] = {4, 5, 6};
int gaps[3][3] = {{1}, {4, 5}, {7}};
int (*rows[2])[3] = {&a3, &b3};
int kept(int i) { static char *words[] = {"alpha", "beta", "gamma"}; static int holes[2][2] = {{3}, {5}}; return words[i][1] + holes[1][0] + holes[0][1]; }
int main(void) {
    int x = 3, y = 4;
    int *lp[2] = {&y, &x};
    char letters[4] = {'o', 'k'};
    unsigned char lbytes[3] = {200, 100};
    row r = {1, 2};
    int again = 0;
    int large[80] = {1, 2, 3};
    long ln[2] = {-5, 7};
    int m2[][2] = {1, 2, 3};
    for (int i = 0; i < 3; i++) { int t[3] = {i}; t[1] += 5; again += t[0] + t[1] + t[2]; }
    large[79] = 9;
    printf("%d %d %d %d %d %d %ld %ld\n", bytes[0], bytes[2], bytes[3], signs[0], signs[1], signs[2], big[0], big[1]);
    printf("%d %d %d %d %d %d %d\n", *gp[1], *lp[0], *lp[1], groww[2], (*rows[1])[2], rows[0][0][1], kept(2));
    printf("%s %d %d %d %d %d %d %d %d\n", letters, letters[3], lbytes[0], lbytes[2], r[1], r[2], again, large[2], large[79] + large[50]);
    printf("%ld %ld %lu %d %d %d %d %d %d\n", ln[0], ln[1], sizeof m2, m2[1][0], m2[1][1], gaps[1][1], gaps[1][2], gaps[2][0], gaps[0][2]);
    return again;
}
