int main() { int a[5]; int *b[2]; return sizeof a[0] * 100 + sizeof b[1] * 10 + sizeof(a + 1) / 8; }
