/* Elements eight bytes wide, so the index counts in eights. */
int main() {
    int x = 1; int y = 2; int z = 3;
    int *a[3];
    a[0] = &x; a[1] = &y; a[2] = &z;
    *a[2] = 7;
    return *a[1] * 10 + z;
}
