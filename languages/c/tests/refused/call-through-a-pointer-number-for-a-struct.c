struct pair { int a; int b; }; int area(struct pair p) { return p.a * p.b; } int main(void) { int (*f)(struct pair) = area; return f(5); }
