/* `sizeof(sizeof(int))` -- 8, under `cc` and here.
 *
 * C11 6.5.3.4 says `sizeof` is worth a `size_t`, which on this machine is an
 * `unsigned long`, eight bytes wide. From 2026-09-22 this subset had no
 * `long`, so `sizeof` was worth an `int` and this program answered 4. It sat
 * in `tests/divergent/` with both answers pinned, and moved here the day
 * `long` arrived: `sizeof` is a `long` now. Not an `unsigned` one, which is
 * a later step, and no program here can see the difference yet, since a
 * size is never negative.
 */
int main() { return sizeof(sizeof(int)); }
