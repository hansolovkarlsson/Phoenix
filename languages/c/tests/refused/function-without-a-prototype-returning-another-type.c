long g(int a) { return a; }
int (*take(void))() { return g; }
int main(void) { return 0; }
