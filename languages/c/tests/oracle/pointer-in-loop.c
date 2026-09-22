int main() {
    int sum = 0;
    int i = 0;
    int *p = &i;
    while (*p < 5) { sum = sum + *p; *p = *p + 1; }
    return sum;
}
