char *malloc(long n);
int main() { char *p; p = malloc(16); p[3] = 7; p[15] = 30; return p[3] + p[15]; }
