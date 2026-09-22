/* `sizeof(sizeof(int))` -- 8 under `cc`, 4 here.
 *
 * C11 6.5.3.4 says `sizeof` is worth a `size_t`, which on this machine is
 * eight bytes wide. `size_t` is a **typedef**, and ROADMAP 6.1 stops the
 * subset before `typedef` on purpose, so there is no way here to name the
 * type this answer ought to have. `sizeof` is worth an `int`, and an `int` is
 * four bytes, so asking for the size of one `sizeof` with another is the one
 * program where the two compilers give different numbers.
 *
 * Every other `sizeof` in `tests/oracle/` agrees, because the answers
 * themselves, 4 for an `int` and 8 for a pointer, are the ones `cc` gives.
 *
 * It is here so the gap has a witness rather than a sentence. The suite pins
 * both answers, so closing it shows up as a failing test with the old number
 * in it -- which is what happens when `typedef` arrives and `size_t` with it.
 */
int main() { return sizeof(sizeof(int)); }
