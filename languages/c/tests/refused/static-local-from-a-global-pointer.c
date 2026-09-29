int *gp; int main(void) { static int *p = gp; return p == 0; }
