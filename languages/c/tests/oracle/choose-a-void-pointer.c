void *malloc(unsigned long n);
void free(void *p);
int putchar(int c);
struct t { int a; int b; };
char *buffer(char *small, unsigned long len) { return len <= 8 ? small : malloc(len); }
int main() {
    char small[8]; char *b; char *c; struct t s; struct t *ps; void *v = &s; char **pp = &b;
    int x = 1; int y = 0; int r = 0; const char *cs = "ok";
    s.a = 5; s.b = 7;
    b = buffer(small, 4); r = r + (b == small);
    c = buffer(small, 100); r = r + (c != small) * 2; c[0] = 'h'; c[1] = 0; putchar(c[0]); free(c);
    ps = y ? v : &s; r = r + ps->b;
    ps = x ? v : &s; r = r + ps->a * 10;
    b = *(char **)(x ? pp : v); r = r + (b == small) * 4;
    r = r + sizeof(x ? v : small) + sizeof(*(char *)(y ? small : v)) * 100;
    putchar(*(const char *)(x ? (const void *)cs : v)); putchar(10);
    return r % 256;
}
