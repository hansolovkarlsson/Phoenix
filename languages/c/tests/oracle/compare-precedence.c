/* Equality is looser than the relations: 0 == (1 < 2) is 0 == 1, which is 0.
   The other grouping is (0 == 1) < 2, which is 0 < 2, which is 1. And a
   comparison is looser than arithmetic: 1 + 2 == 3 is 1. */
int main() { return (0 == 1 < 2) * 10 + (1 + 2 == 3); }
