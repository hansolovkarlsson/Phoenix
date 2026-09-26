struct pair { int a; int b; };
int printf(char *format, ...);
int main() { struct pair p; p.a = 1; p.b = 2; printf("%d\n", p); return 0; }
