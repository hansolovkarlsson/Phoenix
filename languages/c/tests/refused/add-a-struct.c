struct t { int a; };
int main() { struct t s; int i = 0; s.a = 1; i += s; return i; }
