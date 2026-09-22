/* A block on its own, and one as the body of everything. */
int main() {
    int n = 0;
    { n = n + 1; }
    if (n) { n = n + 10; } else { n = n + 100; }
    while (n < 20) { n = n + 1; }
    for (;n < 30;) { n = n + 1; }
    return n;
}
