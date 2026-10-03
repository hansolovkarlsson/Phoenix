/* What Proem uses of <stdio.h>, in the subset. FILE is incomplete, as a
   program never looks inside one. A va_list parameter is written char *,
   which is what __builtin_va_list is on Apple's arm64, so that the subset
   reads the declaration and cc accepts a va_list passed to it. */
#include <stddef.h>
typedef struct __sFILE FILE;
extern FILE *__stdinp;
extern FILE *__stdoutp;
extern FILE *__stderrp;
#define stdin __stdinp
#define stdout __stdoutp
#define stderr __stderrp
#define EOF (-1)
FILE *fopen(const char *p, const char *m);
FILE *fdopen(int fd, const char *m);
int fclose(FILE *f);
int fflush(FILE *f);
int setvbuf(FILE *f, char *b, int m, size_t n);
int fileno(FILE *f);
int ferror(FILE *f);
int getc(FILE *f);
int fgetc(FILE *f);
int ungetc(int c, FILE *f);
int putc(int c, FILE *f);
int fputc(int c, FILE *f);
int putchar(int c);
int fputs(const char *s, FILE *f);
int puts(const char *s);
size_t fread(void *p, size_t s, size_t n, FILE *f);
size_t fwrite(const void *p, size_t s, size_t n, FILE *f);
int printf(const char *fmt, ...);
int fprintf(FILE *f, const char *fmt, ...);
int snprintf(char *s, size_t n, const char *fmt, ...);
int vfprintf(FILE *f, const char *fmt, char *ap);
int vsnprintf(char *s, size_t n, const char *fmt, char *ap);
void perror(const char *s);
int remove(const char *p);
int rename(const char *a, const char *b);
