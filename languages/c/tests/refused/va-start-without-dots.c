typedef __builtin_va_list va_list;
int f(int n) { va_list ap; __builtin_va_start(ap, n); __builtin_va_end(ap); return 0; }
int main(void) { return f(1); }
