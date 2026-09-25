int putchar(int c);
int main() {
    int i; int j; int found = 0; int total = 0;
    for (i = 1; i < 10; i++) {
        j = 0;
        while (1) { j++; { if (j * i > 12) { break; } } total += j; }
        if (i == 4) { { found = i; break; } }
        putchar('0' + j);
    }
    putchar(10);
    return found * 100 + total + i;
}
