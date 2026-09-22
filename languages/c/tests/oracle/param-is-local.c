/* A parameter is a local: assignable, and its own in each frame. */
int dbl(int a) { a = a * 2; return a; }
int main() { int a = 5; return dbl(a) + a; }
