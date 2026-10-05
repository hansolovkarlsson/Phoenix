typedef __builtin_va_list va_list;
int f(int n, ...) { va_list ap; __builtin_va_start(ap, n); __builtin_va_arg(ap, void); return 0; }
int main(void) { return f(1); }
