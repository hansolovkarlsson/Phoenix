typedef __builtin_va_list va_list;
int f(int n, ...) { va_list ap; __builtin_va_start(ap, n); char c = __builtin_va_arg(ap, char); return c; }
int main(void) { return f(1); }
