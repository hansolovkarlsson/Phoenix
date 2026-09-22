/* int is signed, so -1 < 1. An unsigned compare would say 0. And the
   negation of a comparison is -1, which the shell shows as 255. */
int main() { return (-1 < 1) * 100 + -(2 < 3); }
