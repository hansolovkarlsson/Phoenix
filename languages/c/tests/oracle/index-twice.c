/* Two subscripts on the left of an `=`: a place with more than one. */
int main() {
    int r0[2]; int r1[2];
    int *m[2];
    m[0] = r0; m[1] = r1;
    m[1][1] = 4; m[0][1] = 5;
    return r1[1] * 10 + m[0][1];
}
