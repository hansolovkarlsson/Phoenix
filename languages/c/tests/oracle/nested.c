/* Deep enough that the pushes have to nest correctly: every operand is an
   expression whose own operands were pushed and popped before it. */
int main() {
    return ((1 + 2) * (3 + 4) - (5 - 6) * (7 + 8)) / ((9 - 10) * (11 - 12) + 2);
}
