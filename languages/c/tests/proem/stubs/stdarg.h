/* <stdarg.h> left to cc's builtins, which the subset does not have, so that
   a variadic function defined shows as a stop and is not stubbed away. */
typedef __builtin_va_list va_list;
#define va_start(ap, x) __builtin_va_start(ap, x)
#define va_arg(ap, t) __builtin_va_arg(ap, t)
#define va_end(ap) __builtin_va_end(ap)
#define va_copy(d, s) __builtin_va_copy(d, s)
