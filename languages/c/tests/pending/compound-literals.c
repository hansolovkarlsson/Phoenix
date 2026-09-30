int printf(char *format, ...);
struct pair { int a; int b; };
int sum(int *v, int n) { int s = 0; for (int i = 0; i < n; i++) s += v[i]; return s; }
int area(struct pair p) { return p.a * p.b; }
int *shared = (int []){1, 2, 3};
int main(void) {
    struct pair p;
    int *q;
    p = (struct pair){3, 4};
    q = (int [3]){10, 20, 30};
    printf("%d %d %d %d %d %d\n", p.a, p.b, sum(q, 3), sum((int []){1, 2, 3, 4}, 4), area((struct pair){.a = 5, .b = 6}), shared[2]);
    return p.b;
}
