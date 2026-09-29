struct s { int a; }; int main(void) { struct s x; static struct s y = x; return y.a; }
