/* A negative int through the calling convention: passed in w0, stored into a
   slot with `str w0`, and compared there. AAPCS64 leaves the upper half of x0
   unspecified for a 32-bit argument, so nothing downstream may read it. */
int sign(int n) { int m = n; return (m < 0) * 2 + (m == 0 - 9); }
int main() { return sign(0 - 9) * 10 + sign(4); }
