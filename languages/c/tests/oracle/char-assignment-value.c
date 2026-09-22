/* An assignment is worth the value of its left side after it, C11 6.5.16, so
   putting 300 in a `char` is worth 44 and not 300. It is divided before it is
   returned, because the shell keeps eight bits of an exit status and would
   turn 300 into 44 itself, which is how the first version of this program
   passed without the narrowing it was written to check. */
int main() { char c; int i = (c = 300); return i / 10 + ((c = 200) < 0) * 100; }
