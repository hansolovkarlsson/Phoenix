int printf(const char *format, ...);
int puts(const char *s);
static const char *names[] = { "one" "two", "three", "" "" "four" };
int main(void) {
    char a[] = "ab" "cd";
    char b[8] = "x" "y" "z";
    puts("unterminated argument list "
         "invoking macro");
    printf("%d %d %d %s\n", (int)sizeof a, (int)sizeof "a" "bc", b[3], a);
    printf("%s %s %s %d\n", names[0], names[1], names[2],
           (int)sizeof("" ""));
    printf("%s" "%d\n", "x\\" "\"y", 7);
    return sizeof "Proem " "lexer";
}
