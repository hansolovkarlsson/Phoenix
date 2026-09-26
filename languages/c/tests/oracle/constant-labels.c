int classify(int x) {
    switch (x) {
    case 'a' + 1: return 1;
    case 1 << 3: return 2;
    case -2 * 3: return 3;
    case sizeof(int): return 4;
    case (7 > 3) ? 100 : 200: return 5;
    case ~0: return 6;
    }
    return 0;
}
int main() { return classify('b') + classify(8) * 10 + classify(-6) + classify(100) * 4 + classify(4) * 3 + classify(-1) * 7 + classify(9); }
