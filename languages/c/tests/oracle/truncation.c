/* C11 6.5.5: division truncates toward zero. -7 / 2 is -3, which the shell
   shows as 253; a floored quotient would be -4 and 252. There is no unary
   minus yet, so the negative is made by subtraction. */
int main() { return (0 - 7) / 2; }
