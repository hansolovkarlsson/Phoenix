struct t { int a; int b; int c; };
int main() {
    struct t s[4]; struct t *q = s; char text[5]; char *t = text; long k = 2; int a[6]; int *p = a; int i;
    for (i = 0; i < 4; i++) { s[i].a = i; s[i].b = i * 10; s[i].c = i * 100; }
    for (i = 0; i < 6; i++) a[i] = i * i;
    text[0] = 'a'; text[1] = 'b'; text[2] = 'c'; text[3] = 'd'; text[4] = 0;
    q += 2; q->b += 5; q--; q++->c = 7; q -= 2;
    t += 3; t--;
    p += k; p -= -1;
    return q->a + s[1].c + s[2].b + *t + *p + (q + 3 - s);
}
