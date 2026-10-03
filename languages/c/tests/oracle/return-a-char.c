int putchar(int c);
char narrow(int x);
char narrow(int x) { return x; }
unsigned char unarrow(int x) { return x; }
signed char snarrow(long x) { return x; }
char upper(char c) { return c >= 'a' && c <= 'z' ? c - 32 : c; }
unsigned char at(const unsigned char *s, int i) { return s[i]; }
char last(const char *s) { return *s ? (s[1] ? last(s + 1) : *s) : 0; }
int main() {
    char (*f)(int) = narrow; unsigned char (*g)(int) = unarrow;
    long big = 4294967296 + 300; int r = 0;
    putchar(upper('h')); putchar(upper('i')); putchar(upper('!')); putchar(10);
    r = r + (narrow(200) < 0) + (unarrow(200) > 0) * 2 + (narrow(300) == 44) * 4 + (unarrow(-1) == 255) * 8;
    r = r + (f(384) == -128) * 16 + (g(511) == 255) * 32 + (snarrow(big) == 44) * 64;
    r = r + at((const unsigned char *)"\377", 0) + last("phoenix") + sizeof(narrow(1)) + sizeof(narrow(1) + 0);
    return r % 256;
}
