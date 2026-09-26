int printf(char *format, ...);
int which(long v) {
    switch (v) {
    case 4294967296 * 2: return 1;
    case (long)1 << 40: return 2;
    case -4294967296 - 1: return 3;
    case 9223372036854775807 - 1: return 4;
    case 4294967296 / -3: return 5;
    case 9223372036854775807 % 4294967296: return 6;
    case (4294967296 | 1) & -2: return 7;
    case 3000000000 + 3000000000: return 8;
    }
    return 0;
}
int main(void) {
    printf("%d %d %d %d %d %d %d %d %d\n", which(8589934592), which(1099511627776), which(-4294967297),
           which(9223372036854775806), which(-1431655765), which(4294967295), which(4294967296),
           which(6000000000), which(5));
    return which(6000000000);
}
