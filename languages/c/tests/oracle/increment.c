struct t { int a; int b; int c; };
int main() {
    int x[3]; int *p; struct t s[2]; struct t *q; char c = 127; int i; int k = 0; long n = 2000000000;
    x[0] = 1; x[1] = 2; x[2] = 3; p = x; q = s;
    i = *p++; i = i + *++p; q++; c += 1; n += n;
    x[k++] += 10;
    i += (q - s) + (c < 0) + (n > 0) + k; i -= 1; i *= 3; i /= 2;
    return i + x[0] + p[-1]-- + x[1];
}
