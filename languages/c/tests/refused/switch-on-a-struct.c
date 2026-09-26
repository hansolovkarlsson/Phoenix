struct t { int a; };
int main() { struct t s; s.a = 1; switch (s) { case 0: return 1; } return 0; }
