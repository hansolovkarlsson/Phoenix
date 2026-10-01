typedef int T;
int main(void) {
    int (*f)(int T) = 0;
    T x = 3;
    return x + (f != 0);
}
