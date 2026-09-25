int putchar(int c);
int bump(int *count, int value) { *count = *count + 1; putchar('0' + value); return value; }
int main() {
    int n = 0; int r;
    r = bump(&n, 0) && bump(&n, 1);
    r = r * 10 + (bump(&n, 2) || bump(&n, 3));
    r = r * 10 + (bump(&n, 0) || bump(&n, 4));
    r = r * 10 + (bump(&n, 5) && bump(&n, 0) && bump(&n, 6));
    putchar(10);
    return r + n * 100;
}
