struct s { int x; };
int main(void) { struct s v = { 1 }; int (*h)() = 0; return h(v); }
