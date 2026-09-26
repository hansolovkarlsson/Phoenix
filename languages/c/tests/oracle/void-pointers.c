void *malloc(long n);
void free(void *p);
int printf(char *format, ...);
int sum(void *p, int n) { int *q = p; int t = 0; int i; for (i = 0; i < n; i++) t += q[i]; return t; }
int main() {
    int *a = malloc(4 * sizeof(int)); void *v = a; char *c = (char *)v; int r;
    a[0] = 1; a[1] = 2; a[2] = 3; a[3] = 4;
    printf("%d %d %d\n", sum(a, 4), c[4], v == (void *)a);
    r = sum(v, 2) + (v != (void *)0);
    free(a);
    return r;
}
