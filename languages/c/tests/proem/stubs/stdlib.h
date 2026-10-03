/* What Proem uses of <stdlib.h>, in the subset. */
#include <stddef.h>
void *malloc(size_t n);
void *calloc(size_t n, size_t s);
void *realloc(void *p, size_t n);
void free(void *p);
void exit(int c);
void abort(void);
char *getenv(const char *n);
int atoi(const char *s);
long strtol(const char *s, char **e, int b);
unsigned long strtoul(const char *s, char **e, int b);
long long strtoll(const char *s, char **e, int b);
unsigned long long strtoull(const char *s, char **e, int b);
void qsort(void *b, size_t n, size_t s, int (*c)(const void *, const void *));
