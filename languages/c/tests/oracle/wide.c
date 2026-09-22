/* 1000000 does not fit a mov immediate, so the assembler has to find another
   way to load it. Only the low byte reaches the shell: 1000000 mod 256 is 64. */
int main() { return 1000000; }
