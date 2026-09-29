int table[4]; int main(void) { static int *p = &table[1]; return *p; }
