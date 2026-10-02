int printf(const char *format, ...);
int main(void) {
    char s[] = "\a\b\f\r\v\?\t\n";
    const char *ws = " \t\v\f\r";
    int i = 0, sum = 0;
    while (s[i]) { sum = sum * 3 + s[i]; i++; }
    printf("%d %d %d %d %d %d\n", '\a', '\b', '\f', '\r', '\v', '\?');
    printf("%d %d %d\n", (int)sizeof s, (int)sizeof "\v\v", sum);
    printf("%d %d %d\n", ws[1] == '\t', ws[2] == '\v', ws[4]);
    printf("[\?\?-] [\\v]\n");
    return '\r' + '\f';
}
