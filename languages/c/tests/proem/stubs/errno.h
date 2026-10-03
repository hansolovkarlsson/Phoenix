/* What Proem uses of <errno.h>, as Darwin has it. */
extern int *__error(void);
#define errno (*__error())
#define ENOENT 2
#define EIO 5
#define ENOMEM 12
#define EACCES 13
#define EEXIST 17
#define ENOTDIR 20
#define EISDIR 21
#define EINVAL 22
#define ERANGE 34
