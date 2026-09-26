int pick(long x) {
    switch (x) { case 4294967296: return 1; case 0: return 2; case -4294967296: return 3; default: return 4; }
}
int main() {
    char c = -1; int r = 0;
    switch (c) { case 255: r = 10; break; case -1: r = 20; break; }
    switch (c + 1) { case 0: r += 5; }
    return r + pick(4294967296) * 100 % 256 + pick(0) + pick(0 - 4294967296) * 2 + pick(7);
}
