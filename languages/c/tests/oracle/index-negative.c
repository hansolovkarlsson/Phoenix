/* A 32-bit index meeting a 64-bit pointer: -2 has to be sign-extended, and a
   zero-extended one lands four gigabytes away. */
int main() {
    int a[4];
    a[1] = 3;
    int *p = a + 3;
    int i = 0 - 2;
    return p[-2] * 100 + *(p - 2) * 10 + p[i];
}
