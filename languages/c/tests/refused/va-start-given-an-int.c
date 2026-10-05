typedef __builtin_va_list va_list;
int f(int n, ...) { int ap; __builtin_va_start(ap, n); return 0; }
int main(void) { return f(1); }
