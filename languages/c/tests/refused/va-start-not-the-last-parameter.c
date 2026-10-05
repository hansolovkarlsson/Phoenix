typedef __builtin_va_list va_list;
int f(int a, int b, ...) { va_list ap; __builtin_va_start(ap, a); __builtin_va_end(ap); return 0; }
int main(void) { return f(1); }
