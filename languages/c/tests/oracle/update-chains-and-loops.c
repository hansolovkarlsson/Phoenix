int putchar(int c);
int main() {
    int a = 1; int b = 2; int c = 3; int s = 0; int i; int n = 4; char ch = 'a';
    a += b += c *= 2;
    for (i = 0; i < 5; i++) s += i * i;
    while (n--) s -= n;
    for (i = 10; i > 0; i -= 3) putchar(ch++);
    putchar(10);
    return a * 100 + b * 10 + c + s + n + ch;
}
