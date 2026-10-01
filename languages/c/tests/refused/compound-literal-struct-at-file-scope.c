struct pair { int a; int b; }; struct pair g = (struct pair){1, 2}; int main(void) { return g.b; }
