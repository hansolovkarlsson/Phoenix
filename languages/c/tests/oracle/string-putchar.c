int putchar(int c);
int say(char *s) { while (*s != '\0') { putchar(*s); s = s + 1; } putchar('\n'); return 0; }
int main() { say("one"); say("two, and the same one twice"); say("one"); return 0; }
