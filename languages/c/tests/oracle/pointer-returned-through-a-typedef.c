typedef int *ip;
ip f(ip p) { return p; }
int main() { int x; x = 33; return *f(&x); }
