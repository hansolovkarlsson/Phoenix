/* What Proem uses of <sys/stat.h>, in the subset. The members are named
   for checking, not laid out for linking: the probe compiles, it does not
   run. */
struct stat {
    int st_dev; unsigned short st_mode; unsigned short st_nlink; unsigned long st_ino;
    unsigned int st_uid; unsigned int st_gid; int st_rdev;
    long st_atime_s; long st_atime_ns; long st_mtime_s; long st_mtime_ns;
    long st_ctime_s; long st_ctime_ns; long st_btime_s; long st_btime_ns;
    long st_size; long st_blocks; int st_blksize; unsigned int st_flags;
    unsigned int st_gen; int st_lspare; long st_qspare[2];
};
int fstat(int fd, struct stat *s);
#define S_ISREG(m) (((m) & 0170000) == 0100000)
