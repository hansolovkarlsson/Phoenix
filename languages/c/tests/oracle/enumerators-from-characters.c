int printf(const char *format, ...);
enum letters { A = 'a', B, NL = '\n', Q = '\'', HEX = '\x41', OCT = '\101', HIGH = '\xff', SUM = 'z' - 'a' + 1 };
int main(void) {
    enum letters c = HIGH;
    printf("%d %d %d %d %d %d %d %d\n", A, B, NL, Q, HEX, OCT, HIGH, SUM);
    printf("%d %d\n", c < 0, (int)sizeof c);
    return B;
}
