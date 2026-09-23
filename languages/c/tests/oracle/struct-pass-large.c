int putchar(int c);
struct big { int a[5]; char name[3]; };
int total(struct big b) { int s = 0; int i; for (i = 0; i < 5; i = i + 1) { s = s + b.a[i]; b.a[i] = 0; } putchar(b.name[0]); putchar(b.name[1]); putchar(10); return s; }
int main() { struct big b; int i; for (i = 0; i < 5; i = i + 1) b.a[i] = i * 3; b.name[0] = 'o'; b.name[1] = 'k'; return total(b) + total(b) + b.a[4]; }
