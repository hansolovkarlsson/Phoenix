/* Thirteen levels of pointer. Until 2026-10-10 a type's pointer levels came
 * from a table that stopped at twelve, and the thirteenth lost every level:
 * this was refused as "'*' wants a pointer, and this is an int". */
int main(void) { int x = 7; int *p1 = &x; int **p2 = &p1; int ***p3 = &p2; int ****p4 = &p3; int *****p5 = &p4; int ******p6 = &p5; int *******p7 = &p6; int ********p8 = &p7; int *********p9 = &p8; int **********p10 = &p9; int ***********p11 = &p10; int ************p12 = &p11; int *************p13 = &p12; return sizeof(*p13) + *************p13; }
