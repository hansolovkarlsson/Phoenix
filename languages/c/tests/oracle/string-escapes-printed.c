/* Printed, so the oracle compares the bytes and not only how many there are.
   `\'` is here because this machine's assembler refuses it in a string. */
int puts(char *s);
int main() { puts("tab\there, \"quoted\", back\\slash, it\'s, it's, \\'\\\\'"); puts("\n"); return 0; }
