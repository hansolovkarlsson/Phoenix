int puts(char *s);
int first() { puts("first"); return 1; }
int second() { puts("second"); return 2; }
int main() { char *p = "third"; second(); first(); puts(p); return p[1]; }
