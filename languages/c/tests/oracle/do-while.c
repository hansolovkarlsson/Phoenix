int putchar(int c);
int main() {
    int k = 0; int n = 0; int tests = 0; int m = 10;
    do { k++; if (k < 3) continue; n++; } while (tests++, k < 5);
    do { putchar('x'); } while (0);
    do m--; while (m > 7);
    do { if (m == 5) break; m--; } while (1);
    putchar(10);
    return k * 1000 % 256 + n * 10 + tests + m;
}
