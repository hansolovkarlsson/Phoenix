/* fib(10) is 55. Every frame is its own, and a parameter survives the
   two calls made while it is still wanted. */
int fib(int n) { if (n < 2) return n; return fib(n - 1) + fib(n - 2); }
int main() { return fib(10); }
