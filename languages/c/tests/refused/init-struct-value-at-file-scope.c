struct p { int a; }; struct p s; struct w { struct p m; } x = {s}; int main(void) { return x.m.a; }
