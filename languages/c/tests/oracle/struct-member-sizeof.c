struct s { char c; int i; char *p; int a[3]; char b[5]; };
int main() { struct s x; struct s *q; q = &x; return sizeof x.c + sizeof x.i * 10 + sizeof q->p + sizeof x.a + sizeof q->b * 100 - sizeof(struct s); }
