int printf(char *format, ...);
int later(void);
void show(int *n) { printf("%d\n", *n); if (*n > 2) return; *n = *n + 10; }
void nothing(void) { }
int twice(void) { return 2; }
int main(void) {
    int k = 1;
    show(&k); show(&k); nothing(); twice();
    for (show(&k); k < 12; show(&k)) k++;
    return k + twice() + later();
}
int later(void) { return 30; }
