/* The bytes the assembler wrote, counted by walking them, against the length
   `sizeof` worked out from the text. Two routes to one number. */
int length(char *s) { int n = 0; while (s[n] != '\0') n = n + 1; return n; }
int main() {
    int bad = 0;
    if (length("a\tb\\c\"d\'e\n") != sizeof "a\tb\\c\"d\'e\n" - 1) bad = bad + 1;
    if (length("\\\\\\'") != sizeof "\\\\\\'" - 1) bad = bad + 1;
    if (length("\'\"\\\n\t") != sizeof "\'\"\\\n\t" - 1) bad = bad + 1;
    if (length("") != sizeof "" - 1) bad = bad + 1;
    return bad * 10 + length("\\'\\");
}
