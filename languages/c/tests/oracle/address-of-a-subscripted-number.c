/* `&1` is refused and `&1[a]` is not: a subscript is what turns a number into
   a place, because `1[a]` is `*(1 + a)`. This is why the refusal of `&1`
   says it expected `[`. */
int main() { int a[2]; a[1] = 5; return *&1[a]; }
