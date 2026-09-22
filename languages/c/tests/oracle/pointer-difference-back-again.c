/* A difference is an int, and an int is what a subscript takes, including a
   negative one. */
int main() { int a[5]; a[1] = 4; a[4] = 3; int *p = &a[1]; int *q = &a[4]; return q[p - q] * 10 + p[q - p]; }
