/* <stdarg.h> left to cc's builtins, which the subset has had since
   2026-10-04, when a variadic function defined was the last stop in two
   files; it was left to them so that it showed as a stop. */
typedef __builtin_va_list va_list;
#define va_start(ap, x) __builtin_va_start(ap, x)
#define va_arg(ap, t) __builtin_va_arg(ap, t)
#define va_end(ap) __builtin_va_end(ap)
#define va_copy(d, s) __builtin_va_copy(d, s)
