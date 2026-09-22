/* A negative int stored and reloaded through a pointer. `ldr w0` zero-extends,
   so the value in x0 is 0x00000000FFFFFFFB; a comparison that asked x0 rather
   than w0 would call it positive. This is the program that says the compare
   takes its width from its operands. */
int main() { int x = 0; int *p = &x; *p = 0 - 5; return (*p < 0) * 10 + (*p + 15); }
