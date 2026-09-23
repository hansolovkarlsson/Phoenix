int putchar(int c);
struct p { int x; int y; };
struct big { int v[6]; };
struct p shout(int c) { struct p r; putchar(c); r.x = c; r.y = c; return r; }
struct big louder(int c) { struct big b; putchar(c); putchar(10); b.v[0] = c; return b; }
int main() { shout(104); shout(105); louder(33); return 0; }
