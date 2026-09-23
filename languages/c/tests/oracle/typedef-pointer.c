typedef int *intp;
int main() { int a = 5; intp p = &a; intp *q = &p; **q = 7; return a * 10 + sizeof(intp) + sizeof(*q); }
