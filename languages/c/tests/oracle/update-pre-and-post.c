int main() {
    int x = 5; int y; int a[3]; int *p = a; char c = 127; long n = 4294967295;
    a[0] = 10; a[1] = 20; a[2] = 30;
    y = x++ * 10; y = y + x;
    y = y + ++x * 100;
    y = y - x--; y = y - --x;
    y = y + *p++; y = y + *++p;
    y = y + (*p)++; y = y + a[2];
    y = y + p[-1]--; y = y + a[1];
    c++; n++;
    return y % 200 + (c < 0) + (n == 4294967296) * 2 + x;
}
