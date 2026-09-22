/* C11 6.5.2.1 makes `E1[E2]` mean `*((E1) + (E2))`, and `+` commutes. */
int main() { int a[3]; a[2] = 9; 1[a] = 4; return 2[a] * 10 + a[1]; }
