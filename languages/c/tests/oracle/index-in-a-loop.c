int main() {
    int a[10];
    int i;
    for (i = 0; i < 10; i = i + 1) a[i] = i * i;
    int s = 0;
    for (i = 0; i < 10; i = i + 1) s = s + a[i];
    return s;
}
