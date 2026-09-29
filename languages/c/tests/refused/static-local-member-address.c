struct s { int a; int b[2]; }; struct s g; int main(void) { static int *p = &g.a; return *p; }
