int printf(const char *format, ...);
char line[16] = "a\0b";
int main(void) {
    char s[] = "\101\0\12x\x41\x7e\0";
    const char *t = "\1" "2" "\x1" "f";
    int sum = 0, i;
    for (i = 0; i < (int)sizeof s; i++) sum = sum * 7 + s[i];
    printf("%d %d %d %d %d\n", '\0', '\101', '\x41', '\377', '\x80');
    printf("%d %d %d %d\n", (int)sizeof s, sum, t[0], t[1]);
    printf("%d %d %d %d\n", t[2], t[3], (int)sizeof "\0\00\000", "\08"[1]);
    printf("%d %d %d\n", line[0], line[1], line[2]);
    printf("\x48\151\n");
    return '\x7f' - '\177' + s[4];
}
