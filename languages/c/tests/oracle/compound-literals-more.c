int printf(char *format, ...);
struct pair { int a; int b; };
struct holder { int *p; int n; };
typedef struct pair P;
int *one = &(int){42};
struct holder held = { (int []){7, 8, 9}, 3 };
int *back = (int [5]){[4] = 40, [1] = 10, 11};
char *greeting = (char []){"hi"};
char *const *words = (char *const []){"zero", "one", "two"};
int add(struct pair x, struct pair y) { return x.a + x.b + y.a + y.b; }
int total(struct holder h) { int s = 0; for (int i = 0; i < h.n; i++) s += h.p[i]; return s; }
int main(void) {
    int sum = 0;
    for (int i = 0; i < 3; i++) {
        int *v = (int [2]){i, i * 2};
        v[0] += 10;
        sum += v[0] + v[1];
    }
    int *p = &(int){5};
    *p += 1;
    struct holder h = { (int []){1, 2, 3, 4}, 4 };
    int *ptrs[2] = { (int []){100}, (int []){200, 300} };
    char *s = (char [8]){"abc"};
    P q = (P){.b = 9};
    const int *c = (const int []){4, 5, 6};
    printf("%d %d %d %d %d %d\n", sum, *p, total(h), ptrs[0][0] + ptrs[1][1], q.a, q.b);
    printf("%s %d %s %d %d\n", s, (int)sizeof (int []){1, 2, 3}, greeting, *one, total(held));
    printf("%d %d %d %s\n", (int []){5, 6, 7}[2], (struct pair){1, 2}.b, add((P){1, 2}, (P){3, 4}), words[2]);
    printf("%d %c\n", c[1], (char [3]){'x', 'y', 'z'}[1]);
    printf("%d %d %d %d\n", back[1], back[2], back[3], back[4]);
    return (int){3} + *&(int){4};
}
