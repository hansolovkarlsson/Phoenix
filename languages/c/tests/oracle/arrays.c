int printf(const char *fmt, ...);
typedef int row[3];
int grid[2][3];
struct m { int cell[2][2]; char name[2][4]; };
int sum(int n, int a[], int b[][3]) {
    int s = 0;
    for (int i = 0; i < n; i++) s += a[i] + b[i][i];
    return s;
}
int main(void) {
    int a[2][3];
    row r2[2];
    int (*p)[3] = a;
    int *q[3];
    struct m m;
    for (int i = 0; i < 2; i++)
        for (int j = 0; j < 3; j++) { a[i][j] = i * 3 + j; grid[i][j] = 10 * i + j; r2[i][j] = i + j; }
    m.cell[1][0] = 5; m.name[1][0] = 'x';
    q[0] = a[1];
    printf("%d %d %d %d %c\n", a[1][2], p[1][1], (*(p + 1))[0], m.cell[1][0], m.name[1][0]);
    printf("%lu %lu %lu %lu %lu %lu\n", sizeof a, sizeof a[0], sizeof p, sizeof *p, sizeof(int *[3]), sizeof(int (*)[3]));
    printf("%lu %lu %d %d\n", sizeof r2, sizeof(struct m), q[0][1], sum(2, a[1], grid));
    return a[1][1] + grid[1][2];
}
