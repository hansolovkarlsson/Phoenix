char *malloc(long n);
int main() {
    long n = 1000000; char *p;
    n = n * 3000;
    p = malloc(n);
    p[n - 1] = 23; p[0] = 19;
    return p[n - 1] + p[0];
}
