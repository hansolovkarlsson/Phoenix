int main() {
    int a = 0; int b = 1; int c = 2;
    return (a || b && c) + (a && b || c) * 2 + (!a == b) * 4 + (a == 0 && c > b) * 8
         + (1 && 2 || 0 && 3) * 16 + (a < b || b < a) * 32 + -!a * -64;
}
