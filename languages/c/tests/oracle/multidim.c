int printf(char *format, ...);
typedef int (*rowp)[3];
struct cell { char n[2][3]; int x; };
int grid3[2][3][4];
int sum2(int m[2][3]) { return m[1][2] + m[0][0]; }
int main(void) {
    int a[3], b[3], two[2][3];
    int (*pa)[3] = &a;
    int (*ap[2])[3];
    int (*pc)[3][4] = grid3;
    char s[2][4];
    rowp r = two;
    struct cell c;
    static long kept[2][2];
    long total = 0;
    a[0] = 1; a[1] = 2; a[2] = 3; b[2] = 30;
    two[1][2] = 12; two[0][0] = 5; two[1][0] = 7;
    grid3[1][2][3] = 123;
    ap[0] = &a; ap[1] = &b;
    s[1][2] = 'x';
    c.n[1][2] = 'y'; c.x = 99;
    kept[1][1] += 4;
    total += (*pa)[1] + (*ap[0])[2] + (*ap[1])[2] + pc[1][2][3] + r[1][2];
    total += (long)((char *)(&a + 1) - (char *)&a) + (long)sizeof(&a) + (long)sizeof(*&a);
    total += (long)sizeof grid3[1] + (long)sizeof grid3[1][2] + (long)sizeof(struct cell) + c.x;
    total += (long)sizeof(int[2][3]) + (long)sizeof(int (*)[2]) + ((int (*)[3])two)[1][0];
    pa++;
    total += (long)((char *)pa - (char *)a) + (1 ? a : b)[1] + (0, b)[2] + kept[1][1] + sum2(two);
    printf("%ld %c %c %d\n", total, s[1][2], c.n[1][2], r[0][0]);
    return (int)(total % 256);
}
