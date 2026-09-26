void *malloc(long n);
void free(void *p);
int printf(char *format, ...);
typedef void *handle;
int sum(void *p, int n) { int *q = p; int t = 0; int i; for (i = 0; i < n; i++) t += q[i]; return t; }
void *second(void **pp) { return pp[1]; }
int main() {
    int *a = malloc(4 * sizeof(int)); void *v = a; char *c = v; handle h = v; void *two[2]; int r;
    a[0] = 1; a[1] = 2; a[2] = 3; a[3] = 4;
    two[0] = c; two[1] = a + 2;
    printf("%d %d %d %d %ld\n", sum(a, 4), c[4], v == a, sum(second(two), 2), sizeof(void *) + sizeof(two));
    r = sum(h, 2) + (v != c);
    free(a);
    return r;
}
