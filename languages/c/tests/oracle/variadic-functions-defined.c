/* A variadic function defined, C11 7.16, through the builtins <stdarg.h>'s
 * macros are in cc's headers: va_arg of an int, a long past 32 bits, a
 * pointer and an unsigned, va_copy, and a va_list passed on to libc. */
int printf(const char *, ...);
int vsnprintf(char *, unsigned long, const char *, __builtin_va_list);
typedef __builtin_va_list va_list;
long sum(int n, ...) {
    va_list ap;
    long total = 0;
    __builtin_va_start(ap, n);
    for (int i = 0; i < n; i++)
        total += __builtin_va_arg(ap, int);
    __builtin_va_end(ap);
    return total;
}
long wide(const char *tag, ...) {
    va_list ap, again;
    __builtin_va_start(ap, tag);
    __builtin_va_copy(again, ap);
    long a = __builtin_va_arg(ap, long);
    char c = __builtin_va_arg(ap, char *)[0];
    unsigned u = __builtin_va_arg(ap, unsigned);
    long first = __builtin_va_arg(again, long);
    __builtin_va_end(again);
    __builtin_va_end(ap);
    return a + c + u + first;
}
void say(const char *fmt, ...) {
    char msg[64];
    va_list ap;
    __builtin_va_start(ap, fmt);
    vsnprintf(msg, sizeof msg, fmt, ap);
    __builtin_va_end(ap);
    printf("[%s]\n", msg);
}
int main(void) {
    printf("%ld %ld\n", sum(4, 1, 2, 3, -4), wide("t", 5000000000, "A", 4000000000u));
    say("%d and %s and %ld", 7, "eight", -9L);
    return (int)sum(0);
}
