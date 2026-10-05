typedef __builtin_va_list va_list;
int f(int n, ...) { long *ap; return __builtin_va_arg(ap, int); }
int main(void) { return f(1); }
