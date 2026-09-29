struct s { int a; int b[2]; }; struct s g; int main(void) { static int *q = g.b; return *q; }
