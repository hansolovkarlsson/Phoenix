/* A return from inside a branch leaves the function, not the branch. */
int main() { if (2 < 1) return 1; return 2; }
