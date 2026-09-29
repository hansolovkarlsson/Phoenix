int table[4]; int main(void) { static int *p = 1 + table; return p == 0; }
