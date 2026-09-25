int putchar(int c);
int main() {
    int i = 0; int j; int n = 0;
again:
    n++;
    if (n < 3) goto again;
    for (i = 0; i < 5; i++) for (j = 0; j < 5; j++) if (i * j == 6) goto out;
out:
    putchar('0' + i); putchar('0' + j); putchar(10);
    goto end;
    n = 99;
end:
    return n * 10 + i + j;
}
