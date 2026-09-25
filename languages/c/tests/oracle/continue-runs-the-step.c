int main() {
    int i; int n = 0; int steps = 0;
    for (i = 0; i < 10; i++, steps++) { if (i < 5) continue; n++; }
    for (i = 0; i < 20; i += 3) { if (i % 2) continue; n += 10; }
    return n + steps * 2 + i;
}
