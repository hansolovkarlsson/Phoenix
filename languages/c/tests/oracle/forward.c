/* A call above the function it names, which C99 6.5.2.2 allows only
   after a prototype. */
int twice(int x);
int main() { return twice(21); }
int twice(int x) { return x * 2; }
