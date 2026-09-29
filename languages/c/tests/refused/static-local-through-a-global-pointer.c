int *gp; int main(void) { static int *p = &gp[1]; return p == 0; }
