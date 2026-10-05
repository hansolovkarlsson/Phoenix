typedef __builtin_va_list va_list;
int f(int n, ...) { va_list ap; return __builtin_va_start(ap, n); }
int main(void) { return f(1); }
