typedef __builtin_va_list va_list;
int f(int n, ...) { int x; __builtin_va_end(x); return 0; }
int main(void) { return f(1); }
