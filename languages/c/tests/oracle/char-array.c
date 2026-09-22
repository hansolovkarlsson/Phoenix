/* A one-byte store: written as four bytes, `s[0] = 1` would clear `s[1]`. */
int main() { char s[5]; s[1] = 2; s[0] = 1; s[4] = 9; return s[1] * 100 + s[0] * 10 + sizeof s - 5 + s[4] - 9; }
