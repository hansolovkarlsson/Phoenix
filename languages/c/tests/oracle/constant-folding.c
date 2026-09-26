struct t { int a; char b; long c; };
int f(int x) {
    switch (x) {
    case -7 / 2: return 1;
    case -7 % 2: return 2;
    case 1 << 30: return 3;
    case -16 >> 2: return 4;
    case ('a' | 32) - 90: return 5;
    case ~5 & 7: return 6;
    case !0 + (3 > 2 && 1) * 10: return 7;
    case sizeof(struct t) * 2: return 8;
    case 1 ? 40 : 1 / 0: return 9;
    case (2 + 3) * -(4 - 6): return 10;
    }
    return 0;
}
int main() { return f(-3) + f(-1) * 2 + f(1073741824) * 3 + f(-4) + f(7) * 5 + f(2) + f(11) + f(48) + f(40) + f(10) * 3; }
