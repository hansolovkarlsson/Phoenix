/* ?: between two pointers to one type is const at each level either arm
 * is, C11 6.5.15p6: what is under the const level is still written. */
int main(void) {
    int a = 1, b = 2;
    int *p = &a, *r = &b;
    int *const *qq = &r;
    int **pp = &p;
    const int *q = &b;
    int c = 1;
    **(c ? pp : qq) = 5;
    **(c ? qq : pp) += 2;
    return a * 10 + *(c ? q : p) + *(c ? p : q);
}
