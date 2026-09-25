int putchar(int c);
int pick(int *count, int i) { *count = *count + 1; putchar('0' + i); return i; }
int main() {
    int x[4]; int k = 0; int calls = 0; int *p = x;
    x[0] = 1; x[1] = 2; x[2] = 3; x[3] = 4;
    x[k++] += 10;
    x[pick(&calls, 2)] *= 5;
    x[pick(&calls, 3)]++;
    ++x[pick(&calls, 1)];
    *p++ -= 4;
    putchar(10);
    return x[0] + x[1] * 2 + x[2] * 3 + x[3] * 4 + k * 100 + calls * 1000 % 256 + (p - x);
}
