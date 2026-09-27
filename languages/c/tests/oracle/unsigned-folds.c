int printf(char *format, ...);
unsigned int wrapped = 4294967295u + 2;
unsigned int product = 100000u * 100000u;
unsigned int negated = -1u;
unsigned int inverted = ~5u;
unsigned int less = 1u - 2;
unsigned char small = (unsigned char)300;
unsigned int top = (unsigned int)-1 >> 28;
unsigned int shifted = 3u << 31;
unsigned int half = 4294967295u / 2;
unsigned int rem = -1u % 10;
unsigned int mixed = 0xfffffff0 & 0xff | 0x100u ^ 3;
long picked = 1 ? -1 : 0u;
int below = -1 < 1ul;
int above = 0x80000000u > 5;
int widest = 0xFFFFFFFFFFFFFFFFul > 1;
int signs = -2 < -1 && 2 * 3 == 6;
unsigned int square = 0xffffffffu * 0xffffffffu;
long squarewide = 0xffffffffu * 0xfffffffeu + 0L;
long widened = (1u - 2) + 0L;
long negwide = -1u + 0L;
long invwide = ~5u + 0L;
long castwide = (unsigned int)-1 + 0L;
int ucharwide = (unsigned char)200 + 0;
unsigned int ldiv = -1 / 2u;
unsigned int rdiv = 7u / -1;
int cmpu = -1 < 1u;
int bigpos = 9223372036854775808 > 0;
unsigned long hexsign = 0x8000000000000000;
unsigned long octsign = 01000000000000000000000;
int pick(unsigned int u) {
    switch (u) {
    case -3: return 1;
    case 0xFFFFFFFF * 2u: return 2;
    case 100000u * 100000u: return 3;
    case (unsigned int)-1 / 3: return 4;
    }
    return 0;
}
int main(void) {
    printf("%u %u %u %u %u %u\n", wrapped, product, negated, inverted, less, small);
    printf("%u %u %u %u %u %ld\n", top, shifted, half, rem, mixed, picked);
    printf("%d %d %d %d\n", below, above, widest, signs);
    printf("%u %ld %ld %ld %ld %ld %d\n", square, squarewide, widened, negwide, invwide, castwide, ucharwide);
    printf("%u %u %d %d %lu %lu\n", ldiv, rdiv, cmpu, bigpos, hexsign, octsign);
    printf("%d %d %d %d %d\n", pick(4294967293u), pick(4294967294u), pick(1410065408), pick(1431655765), pick(7));
    return pick(-3) + pick(-2);
}
