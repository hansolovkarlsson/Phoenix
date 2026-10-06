/* A name in scope in its own initialiser, C11 6.2.1p7, where its
 * declarator has a '*' in parentheses: a pointer to a function called
 * through itself, a pointer to an array sized by itself, its own
 * address, in a local, a static local and a global, with
 * locals before and after it so its slot is the one it names, and
 * beside a type of another with parentheses of its own. */
int printf(const char *, ...);
int seven(void) { return 7; }
int arr[3] = { 1, 2, 3 };
void (*gself) = &gself;
int (*gp)[3] = (int (*)[3])sizeof *gp;
long (*gs)[4] = (long (*)[4])sizeof(*gs);
int (*gf)(void) = (int (*)(void))sizeof gf;
int main(void) {
    int before = 5;
    int (*f)(void) = (sizeof f == 8) ? seven : 0;
    int (*p)[3] = (sizeof *p == 12) ? &arr : 0;
    void *(*self) = (void *)&self;
    char (*q)[5] = (char (*)[5])(sizeof(long (*)[9]) + sizeof *q);
    static void (*sself) = &sself;
    static long (*sl)[2] = (long (*)[2])sizeof *sl;
    int after = 6;
    printf("%d %d %d %d\n", f(), (*p)[2], self == (void *)&self, (int)(long)q);
    printf("%d %d\n", sself == (void *)&sself, (int)(long)sl);
    printf("%d %d %d\n", gself == (void *)&gself, (int)(long)gp, before + after);
    printf("%d %d\n", (int)(long)gs, (int)(long)gf);
    return f() + (int)(long)q;
}
