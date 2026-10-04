int main(void) { int a = 1; int *p = &a; int *const *qq = &p; int **pp = &p; int c = 1; *(c ? pp : qq) = 0; return a; }
