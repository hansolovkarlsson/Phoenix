/* `sizeof(p - q)` -- 8 under `cc`, 4 here.
 *
 * C11 6.5.6 says the difference of two pointers is a `ptrdiff_t`, which on
 * this machine is eight bytes wide. `ptrdiff_t` is a **typedef**, and ROADMAP
 * 6.1 stops the subset before `typedef`, so the difference is an `int` here,
 * which is what it was in K&R's first edition, before ANSI C gave it a name.
 * It is `sizeof(sizeof(int))` again, decided the same way on 2026-09-22 and
 * to be revisited with it when `typedef` arrives.
 *
 * Every difference in `tests/oracle/` agrees, because the count of elements
 * between two pointers into one array fits in an `int` either way.
 */
int main() { int a[2]; return sizeof(&a[1] - a); }
