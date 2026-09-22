int five() { return 5; }
int main() { int x = 0; int *p = &x; *p = five(); return x; }
