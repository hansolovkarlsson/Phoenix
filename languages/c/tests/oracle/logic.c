int putchar(int c);
int say(int c) { putchar(c); return c; }
int main() {
    int a = 0;
    if (a != 0 && say('x')) a = 5;
    if (a == 0 || say('y')) a = a + 1;
    putchar('\n');
    return a + !0 + !7 + (say('z') && 0) + (0 || 3);
}
