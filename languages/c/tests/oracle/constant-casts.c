int main() {
    int c = 45; int r = 0;
    switch (c) { case (char)300: r = 1; break; case (int)4294967341: r = 2; break; }
    switch (-56) { case (char)200: r = r + 10; break; }
    return r + (int)sizeof((char)c) + (int)sizeof((long)c);
}
