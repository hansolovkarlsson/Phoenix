int putchar(int c);
int main() {
    int i; int j; int n = 0; int k = 0;
    for (i = 0; i < 10; i++) { if (i == 7) break; if (i % 2) continue; n += i; }
    while (1) { k++; if (k < 5) continue; break; }
    for (i = 0; i < 3; i++) for (j = 0; j < 10; j++) { if (j == 2) break; putchar('a' + i); }
    do { n++; } while (n < 3);
    do n += 100; while (0);
    for (j = 0; j < 4; j++) ;
    ;;
    putchar(10);
    return n + k * 10 + j + i;
}
