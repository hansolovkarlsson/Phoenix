int putchar(int c);
int kind(int c) {
    switch (c) {
    case 'a': case 'e': case 'i': case 'o': case 'u': return 1;
    case ' ': return 2;
    case -1: return 3;
    default: return 0;
    }
}
int main() {
    int i; int n = 0; char *s = "hi you";
    for (i = 0; s[i]; i++) n = n * 3 + kind(s[i]);
    for (i = 0; i < 6; i++) {
        switch (i) {
        case 0: putchar('z');
        case 1: putchar('o'); break;
        default: putchar('d');
        case 4: putchar('f'); continue;
        case 3: break;
        }
        putchar('.');
    }
    putchar(10);
    return (n + kind(-1)) % 256;
}
