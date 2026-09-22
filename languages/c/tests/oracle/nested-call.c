/* Calls as arguments, and a push in flight around the whole thing:
   1 + (3 + 7) * 2 is 21. */
int add(int a, int b) { return a + b; }
int main() { return 1 + add(add(1, 2), add(3, 4)) * 2; }
