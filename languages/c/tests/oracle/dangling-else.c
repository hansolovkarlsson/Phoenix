/* The else belongs to the nearest if, C11 6.8.4.1: x is 2. Bound to the
   outer if, the else would not run and x would be 0. */
int main() { int x = 0; if (1) if (0) x = 1; else x = 2; return x; }
