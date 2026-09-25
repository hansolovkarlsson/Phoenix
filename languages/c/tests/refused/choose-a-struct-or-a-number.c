struct t { int a; };
int main() { struct t s; int x = 1; s.a = 1; return (x ? s : 1).a; }
