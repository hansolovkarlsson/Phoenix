/* `sizeof(p - q)` -- 8, under `cc` and here.
 *
 * C11 6.5.6 says the difference of two pointers is a `ptrdiff_t`, which on
 * this machine is a `long`. From 2026-09-22 this subset had no `long`, so the
 * difference was an `int`, as it was in K&R's first edition, and this
 * program answered 4. It sat in `tests/divergent/` beside
 * `sizeof-of-sizeof.c` and moved here with it, the day `long` arrived.
 */
int main() { int a[2]; return sizeof(&a[1] - a); }
