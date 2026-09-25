int main() {
    int a = 12; char c = 100; long big = 6442450943; int m = 7; int s = 1;
    a &= 10; a |= 5; a ^= 3;
    c <<= 1; c >>= 2;
    big &= -2; big >>= 30;
    m <<= big; s <<= 3; s >>= 1;
    return a + c + big + m + s + (+c) + sizeof(+c) * 10;
}
