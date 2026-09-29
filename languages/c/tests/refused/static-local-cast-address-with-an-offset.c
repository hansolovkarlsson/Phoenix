int table[4]; int main(void) { static char *p = (char *)table + 1; return p == 0; }
