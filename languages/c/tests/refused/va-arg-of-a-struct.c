typedef __builtin_va_list va_list;
struct s { int x; }; int f(int n, ...) { va_list ap; __builtin_va_start(ap, n); struct s v = __builtin_va_arg(ap, struct s); return v.x; }
int main(void) { return f(1); }
