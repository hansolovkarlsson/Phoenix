/* An inner block declares its own x, which shadows and then goes away. */
int main() { int x = 1; { int x = 2; x = x + 1; } return x; }
