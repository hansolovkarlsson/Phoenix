int main() {
    int x = 5; int y = 6;
    int *a[2];
    a[0] = &x; a[1] = &y;
    int **pp = a;
    return **(pp + 1) * 10 + *pp[0];
}
