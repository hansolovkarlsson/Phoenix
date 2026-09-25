int putchar(int c);
int main() {
    int a[6]; int i = 0; int found = 0;
    a[0] = 3; a[1] = 8; a[2] = 0; a[3] = 5; a[4] = 7; a[5] = 9;
    while (i < 6 && !found) { if (a[i] == 0 || a[i] > 8) found = i + 1; else i = i + 1; }
    for (i = 0; i < 6 && a[i]; i = i + 1) putchar('a' + i);
    if (!(i == 2) || found != 3) return 99;
    putchar(10);
    return found * 10 + i;
}
