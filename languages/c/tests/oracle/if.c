/* A taken branch and one not taken. */
int main() { int x = 0; if (1 < 2) x = 5; if (2 < 1) x = 7; return x; }
