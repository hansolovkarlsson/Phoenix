int add(int a, int b) { return a + b; } struct s { int (*f)(int); }; int main(void) { struct s x = {add}; return x.f != 0; }
