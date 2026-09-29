int main(void) { int a = 1; static int *p = &a; return *p; }
