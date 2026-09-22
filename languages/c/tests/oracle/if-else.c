/* Both arms, one program each way. */
int main() {
    int x = 3;
    int y = 0;
    if (x == 3) y = 10; else y = 20;
    if (x == 4) y = y + 1; else y = y + 2;
    return y;
}
