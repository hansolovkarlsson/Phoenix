int main(void) { int a = 1; const int b = 2; int *p = &a; const int *q = &b; int c = 1; *(c ? p : q) = 3; return a; }
