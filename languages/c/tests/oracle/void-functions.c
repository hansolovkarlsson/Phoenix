int printf(char *format, ...);
void show(int *n) { printf("%d\n", *n); if (*n > 2) return; *n = *n + 10; }
void nothing(void) { }
int twice(void) { return 2; }
int main(void) {
    int k = 1;
    show(&k); show(&k); nothing(); (void)k; (void)twice();
    for (show(&k); k < 12; show(&k)) k++;
    return k + twice();
}
