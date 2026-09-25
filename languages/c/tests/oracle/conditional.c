int putchar(int c);
struct t { int a; int b; };
int say(int c) { putchar(c); return c; }
int main() {
    int x = 3; int y = 0; long big = 4294967296; char c = -5; int a[2]; int *p = a; int *q = a + 1;
    struct t s; struct t u; struct t w; int r;
    a[0] = 7; a[1] = 9; s.a = 1; s.b = 2; u.a = 30; u.b = 40;
    r = x ? say('a') : say('b');
    r = r + (y ? say('c') : say('d'));
    r = r + (y ? 1 : x > 2 ? 20 : 300);
    r = r + sizeof(x ? x : big) + sizeof(x ? c : c) * 10;
    r = r + *(x ? q : p) + (y ? p : q)[-1];
    w = x ? u : s; r = r + w.b + (y ? s : u).a;
    r = r + ((x ? big : x) > 4294967295) + ((y ? big : c) < 0) * 2;
    putchar(10);
    return r % 256;
}
