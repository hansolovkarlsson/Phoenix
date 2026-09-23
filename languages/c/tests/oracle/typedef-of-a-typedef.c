typedef int a;
typedef a *b;
typedef b c;
int main() { a v = 3; c p = &v; b *q = &p; return **q + sizeof(c) * 10 + sizeof(a) * 100; }
