/* A local read back in its own assignment, twice over. */
int main() {
    int x = 3;
    x = x * x;
    x = x + 1;
    return x;
}
