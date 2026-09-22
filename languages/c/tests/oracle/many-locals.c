/* Five locals, so the frame is 40 bytes rounded to 48, and each slot has
   to be its own: a wrong offset makes two of these share. */
int main() {
    int a = 1;
    int b = 2;
    int c = 3;
    int d = 4;
    int e = 5;
    return a + b * 10 + c * 100 - d - e * 2;
}
