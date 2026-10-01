struct p { int a; }; struct p x = {[0] = 1}; int main(void) { return x.a; }
