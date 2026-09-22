/* All eight registers, each weighted so that a swap shows. */
int f(int a, int b, int c, int d, int e, int g, int h, int i) {
    return a + b * 2 + c * 3 + d * 4 + e * 5 + g * 6 + h * 7 + i * 8;
}
int main() { return f(1, 2, 3, 4, 5, 6, 7, 8); }
