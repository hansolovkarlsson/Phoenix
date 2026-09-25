int main() {
    long big = 4294967296; char c = -128; int zero = 0; int *p = &zero; int *none = 0;
    return !!5 + !-1 * 2 + (!0 == 1) * 4 + !big * 8 + (big && 1) * 16
         + !c * 32 + (!none && p) * 64 + !p * 128;
}
