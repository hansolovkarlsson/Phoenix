void *malloc(long n);
int main(void) {
    unsigned int k = (unsigned int)3000000000;
    char *p = malloc(3000000016);
    p[k] = 7; p[k + 9] = 30;
    return *(p + k) + p[k + 9];
}
