int main(void) { int v = 1; *(const int *)&v = 2; return v; }
