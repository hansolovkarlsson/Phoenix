/* What Proem uses of <time.h>, in the subset, with Darwin's struct tm. */
#include <stddef.h>
typedef long time_t;
struct tm {
    int tm_sec; int tm_min; int tm_hour; int tm_mday; int tm_mon; int tm_year;
    int tm_wday; int tm_yday; int tm_isdst; long tm_gmtoff; char *tm_zone;
};
time_t time(time_t *t);
struct tm *localtime(const time_t *t);
struct tm *gmtime(const time_t *t);
size_t strftime(char *s, size_t n, const char *f, const struct tm *tm);
