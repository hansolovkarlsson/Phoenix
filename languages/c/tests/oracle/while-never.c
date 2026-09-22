/* A loop whose condition is false at once runs no times. */
int main() { int x = 4; while (x < 0) x = 99; return x; }
