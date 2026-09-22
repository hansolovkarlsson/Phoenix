/* Comparisons chain and group to the left: (3 > 2) > 1 is 1 > 1, which is 0.
   The other grouping is 3 > (2 > 1), which is 3 > 1, which is 1. */
int main() { return 3 > 2 > 1; }
