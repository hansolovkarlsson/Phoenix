/* 1 + 4 + 9 + ... + 100 is 385, which is 129 to the shell. */
int main() {
    int s = 0;
    int i;
    for (i = 1; i <= 10; i = i + 1) s = s + i * i;
    return s;
}
