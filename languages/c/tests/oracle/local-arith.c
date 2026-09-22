/* The result is the last assignment, not the first, and the offsets have
   to survive an expression that pushes between the store and the load. */
int main() { int x = 1; int y = 2; x = (x + y) * (y - x) + x; return x - y; }
