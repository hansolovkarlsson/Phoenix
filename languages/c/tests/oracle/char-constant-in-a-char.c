int main() { char s[4]; s[0] = 'h'; s[1] = 'i'; s[2] = '!'; s[3] = '\0'; char *p = s; int n = 0; while (*p != '\0') { n = n + 1; p = p + 1; } return n * 10 + (s[1] - 'a'); }
