int printf(char *format, ...);
int main() {
    int a = 100000; long big = 4294967301; int x = 258; char *bytes = (char *)&x;
    printf("%ld %d %d %d\n", (long)a * a, (int)big, (char)300, (char)200);
    printf("%d %d %ld\n", bytes[0], bytes[1], (long)(char *)-1);
    printf("%ld %d\n", (long)(bytes + 3) - (long)bytes, (int)(big - 5) ? 1 : 2);
    return (char)(x + 42);
}
