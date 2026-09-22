// A return of nothing in particular, and the two comment shapes on the way.
/* The exit status is the low eight bits of what main returns, which is why
   the oracle compares it modulo 256 and why 0 is the honest test here. */
int main()
{
    return 0;
}
